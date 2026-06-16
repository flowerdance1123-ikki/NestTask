from pathlib import Path
from datetime import datetime
import re
import shutil
import subprocess
import uuid

from fastapi import FastAPI, Form, File, UploadFile, HTTPException, Body
import json as _json
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.requests import Request
from typing import Optional
from pydantic import BaseModel, ConfigDict, ValidationError, field_validator

from .config import (
    TEMPLATE_MAP, UPLOAD_DIR, TEMP_DIR, OUTPUT_DIR,
    DOCS_TEMPLATES_DIR,
    DEFAULT_THERAPIST_NAME, DEFAULT_NOTES,
    COVER_LETTER_NAME_X_RIGHT, COVER_LETTER_NAME_Y, COVER_LETTER_NAME_FONT_SIZE,
    GEMINI_API_KEY,
)
from .services.pptx_generator import generate_pptx
from .services.pdf_generator import generate_cover_letter, copy_survey
from .services.filename_utils import safe_filename

_ALLOWED_TEMPLATE_TYPES = {"bodymap", "photo", "qr"}


class AiJsonOutput(BaseModel):
    model_config = ConfigDict(extra="ignore", str_strip_whitespace=True)

    template_type:   Optional[str] = None
    patient_name:    str = ""
    therapist_name:  str = ""
    created_date:    str = ""
    body_status:     str = ""
    recent_state:    str = ""
    notes:           str = ""
    shared_points:   str = ""
    photo_1_caption: str = ""
    photo_2_caption: str = ""
    main_title:      str = ""
    main_url:        str = ""
    sub_title_1:     str = ""
    sub_url_1:       str = ""
    main_qr_url:     str = ""
    sub_qr_url:      str = ""

    @field_validator(
        "patient_name", "therapist_name", "created_date",
        "body_status", "recent_state", "notes", "shared_points",
        "photo_1_caption", "photo_2_caption", "main_title", "sub_title_1",
        mode="before",
    )
    @classmethod
    def _coerce_str(cls, v):
        return "" if v is None else str(v)

    @field_validator("template_type", mode="before")
    @classmethod
    def _validate_template_type(cls, v):
        if not v:
            return None
        s = str(v).strip().lower()
        if s not in _ALLOWED_TEMPLATE_TYPES:
            raise ValueError(f"template_type は bodymap/photo/qr のいずれかが必要です: {v!r}")
        return s

    @field_validator("main_url", "sub_url_1", "main_qr_url", "sub_qr_url", mode="before")
    @classmethod
    def _validate_url(cls, v):
        if not v:
            return ""
        s = str(v).strip()
        if not re.match(r"^https?://", s, re.IGNORECASE):
            return ""
        return s[:500]

    @field_validator("body_status", "recent_state", "notes", mode="after")
    @classmethod
    def _max_400(cls, v):
        return v[:400]

    @field_validator("shared_points", mode="after")
    @classmethod
    def _max_200(cls, v):
        return v[:200]

    @field_validator(
        "therapist_name", "photo_1_caption", "photo_2_caption",
        "main_title", "sub_title_1",
        mode="after",
    )
    @classmethod
    def _max_100(cls, v):
        return v[:100]

    @field_validator("created_date", "patient_name", mode="after")
    @classmethod
    def _max_50(cls, v):
        return v[:50]


app = FastAPI(title="情報共有シートDX")

_static_dir = Path(__file__).parent / "static"
_templates_dir = Path(__file__).parent / "templates_html"

app.mount("/static", StaticFiles(directory=str(_static_dir)), name="static")
templates = Jinja2Templates(directory=str(_templates_dir))


def _today_str() -> str:
    d = datetime.now()
    return f"{d.year}年{d.month}月{d.day}日"


def _looks_like_url(value: str) -> bool:
    return bool(re.match(r"^https?://\S+", value.strip()))


@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    # Starlette 0.36+ の新API: request を別引数で渡す
    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={
            "default_therapist": DEFAULT_THERAPIST_NAME,
            "default_notes": DEFAULT_NOTES,
            "today": _today_str(),
        },
    )


@app.post("/create")
async def create_pptx(
    request: Request,
    template_type: str = Form(...),
    patient_name: str = Form(...),
    therapist_name: str = Form(""),
    created_date: str = Form(""),
    body_status: str = Form(...),
    recent_state: str = Form(...),
    notes: str = Form(""),
    shared_points: str = Form(""),
    photo_1_caption: str = Form(""),
    photo_2_caption: str = Form(""),
    main_title: str = Form(""),
    main_url: str = Form(""),
    sub_title_1: str = Form(""),
    sub_url_1: str = Form(""),
    photo_1: UploadFile = File(None),
    photo_2: UploadFile = File(None),
    # ── 送付書類セット ──────────────────────────────────────────────────
    create_cover_letter: str = Form(""),      # "1" のとき送付状を作成
    cover_letter_therapist: str = Form(""),   # 送付状用担当者名（空なら therapist_name を使用）
    survey_type: str = Form("none"),          # "none" / "first" / "followup"
):
    # --- バリデーション ---
    if template_type not in TEMPLATE_MAP:
        raise HTTPException(400, "テンプレートの種類が不正です。")
    if not patient_name.strip():
        raise HTTPException(400, "患者名を入力してください。")
    if not body_status.strip():
        raise HTTPException(400, "現在の身体状況を入力してください。")
    if not recent_state.strip():
        raise HTTPException(400, "最近のご様子を入力してください。")
    if template_type == "qr" and not main_url.strip():
        raise HTTPException(400, "動画QRタイプではメイン動画URLが必要です。")

    warnings = []

    if template_type == "qr":
        if main_url.strip() and not _looks_like_url(main_url):
            warnings.append("メイン動画URLの形式が正しくない可能性があります。https:// から始まるURLを入力してください。")
        if sub_url_1.strip() and not _looks_like_url(sub_url_1):
            warnings.append("サブ動画URLの形式が正しくない可能性があります。https:// から始まるURLを入力してください。")

    # --- 写真の保存 ---
    session_id = uuid.uuid4().hex
    upload_session_dir = UPLOAD_DIR / session_id
    upload_session_dir.mkdir(parents=True, exist_ok=True)

    photo_1_path = ""
    photo_2_path = ""

    def _save_upload(upload: UploadFile, filename: str) -> Path:
        suffix = Path(upload.filename).suffix.lower()
        if suffix not in (".jpg", ".jpeg", ".png"):
            raise HTTPException(400, f"写真は jpg / jpeg / png に対応しています（受け取ったファイル: {upload.filename}）")
        dest = upload_session_dir / filename
        with open(dest, "wb") as f:
            shutil.copyfileobj(upload.file, f)
        return dest

    if template_type == "photo":
        if photo_1 and photo_1.filename:
            try:
                p = _save_upload(photo_1, f"photo_1{Path(photo_1.filename).suffix.lower()}")
                photo_1_path = str(p)
            except HTTPException:
                raise
            except Exception:
                warnings.append("写真1が読み込めませんでした。jpg / jpeg / png の画像を選んでください。")
        else:
            warnings.append("写真1がアップロードされていません。写真なしで作成します。")

        if photo_2 and photo_2.filename:
            try:
                p = _save_upload(photo_2, f"photo_2{Path(photo_2.filename).suffix.lower()}")
                photo_2_path = str(p)
            except HTTPException:
                raise
            except Exception:
                warnings.append("写真2が読み込めませんでした。jpg / jpeg / png の画像を選んでください。")

    # --- データ組み立て ---
    replacements = {
        "patient_name": patient_name.strip(),
        "therapist_name": (therapist_name.strip() or DEFAULT_THERAPIST_NAME),
        "created_date": (created_date.strip() or _today_str()),
        "body_status": body_status.strip(),
        "recent_state": recent_state.strip(),
        "notes": notes.strip(),
        "shared_points": shared_points.strip(),
        "photo_1_caption": photo_1_caption.strip(),
        "photo_2_caption": photo_2_caption.strip(),
        "photo_1_path": photo_1_path,
        "photo_2_path": photo_2_path,
        "main_title": main_title.strip(),
        "main_url": main_url.strip(),
        "sub_title_1": sub_title_1.strip(),
        "sub_url_1": sub_url_1.strip(),
    }

    # --- PPTX生成 ---
    template_path = TEMPLATE_MAP[template_type]
    timestamp = datetime.now().strftime("%Y%m%d_%H%M")
    safe_name = safe_filename(patient_name)
    base_name = f"JKS_{safe_name}_{template_type}_{timestamp}"
    filename = f"{base_name}.pptx"
    output_path = OUTPUT_DIR / filename
    temp_dir = TEMP_DIR / session_id

    try:
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        stats = generate_pptx(template_path, replacements, output_path, temp_dir)
    except FileNotFoundError as e:
        raise HTTPException(500, str(e))
    except Exception as e:
        raise HTTPException(500, f"PPTX作成中にエラーが発生しました。\n詳細: {e}")
    finally:
        # 一時ファイルを削除（個人情報保護のため処理後は残さない）
        shutil.rmtree(temp_dir, ignore_errors=True)
        shutil.rmtree(upload_session_dir, ignore_errors=True)

    for tag in stats.get("unresolved_tags", []):
        warnings.append(f"テンプレートに未置換のタグが残っています: {tag}")

    # --- 送付書類セット生成 ---
    pdf_files: list[dict] = []

    # 送付状
    if create_cover_letter == "1":
        cl_therapist = (cover_letter_therapist.strip()
                        or replacements["therapist_name"])
        cl_filename = f"{base_name}_送付状.pdf"
        cl_path = OUTPUT_DIR / cl_filename
        try:
            generate_cover_letter(
                base_pdf_path=DOCS_TEMPLATES_DIR / "cover_letter_base.pdf",
                therapist_name=cl_therapist,
                output_path=cl_path,
                name_x_right=COVER_LETTER_NAME_X_RIGHT,
                name_y=COVER_LETTER_NAME_Y,
                font_size=COVER_LETTER_NAME_FONT_SIZE,
            )
            pdf_files.append({"filename": cl_filename, "label": "送付状"})
        except FileNotFoundError as e:
            warnings.append(str(e))
        except Exception as e:
            warnings.append(f"送付状の作成中にエラーが発生しました。\n詳細: {e}")

    # アンケート
    if survey_type in ("first", "followup"):
        survey_src_map = {
            "first":    ("family_survey_first.pdf",   "ご家族向けアンケート（初回）"),
            "followup": ("family_survey_followup.pdf", "ご家族向けアンケート（2回目以降）"),
        }
        src_name, label = survey_src_map[survey_type]
        survey_suffix = "アンケート_初回" if survey_type == "first" else "アンケート_2回目以降"
        sv_filename = f"{base_name}_{survey_suffix}.pdf"
        sv_path = OUTPUT_DIR / sv_filename
        try:
            copy_survey(
                survey_pdf_path=DOCS_TEMPLATES_DIR / src_name,
                output_path=sv_path,
            )
            pdf_files.append({"filename": sv_filename, "label": label})
        except FileNotFoundError as e:
            warnings.append(str(e))
        except Exception as e:
            warnings.append(f"アンケートのコピー中にエラーが発生しました。\n詳細: {e}")

    return {
        "ok": True,
        "filename": filename,
        "pdf_files": pdf_files,
        "warnings": warnings,
        "stats": stats,
    }


@app.get("/download/{filename}")
async def download(filename: str):
    # パストラバーサル防止
    if "/" in filename or "\\" in filename or ".." in filename:
        raise HTTPException(400, "不正なファイル名です。")
    path = OUTPUT_DIR / filename
    if not path.exists():
        raise HTTPException(404, "ファイルが見つかりません。もう一度作成してください。")

    # 拡張子に応じた MIME タイプを設定
    suffix = path.suffix.lower()
    media_type_map = {
        ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        ".pdf":  "application/pdf",
    }
    media_type = media_type_map.get(suffix, "application/octet-stream")

    return FileResponse(
        path=str(path),
        media_type=media_type,
        filename=filename,
    )


@app.post("/open_output_folder")
async def open_output_folder():
    """出力フォルダをFinder（macOS）で開く"""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    try:
        subprocess.Popen(["open", str(OUTPUT_DIR)])
    except Exception as e:
        raise HTTPException(500, f"フォルダを開けませんでした。\n詳細: {e}")
    return {"ok": True}


@app.post("/open_file/{filename}")
async def open_file(filename: str):
    """完成ファイルをmacOSのデフォルトアプリで開く（pywebview用）"""
    # パストラバーサル防止
    if "/" in filename or "\\" in filename or ".." in filename:
        raise HTTPException(400, "不正なファイル名です。")
    path = OUTPUT_DIR / filename
    if not path.exists():
        raise HTTPException(404, "ファイルが見つかりません。もう一度作成してください。")
    try:
        subprocess.Popen(["open", str(path)])
    except Exception as e:
        raise HTTPException(500, f"ファイルを開けませんでした。\n詳細: {e}")
    return {"ok": True}


# ─────────────────────────────────────────────────────────────
# Gemini API：日報テキスト → JSON生成
# ─────────────────────────────────────────────────────────────

@app.post("/api/generate_json")
async def generate_json_from_report(
    request: Request,
    body: dict = Body(...),
):
    """日報・報告書テキストをGemini APIでJSON化する"""

    if not GEMINI_API_KEY:
        raise HTTPException(500, "Gemini APIキーが設定されていません。.envファイルを確認してください。")

    report_text = (body.get("report_text") or "").strip()
    if not report_text:
        raise HTTPException(400, "テキストが入力されていません。")

    today = _today_str()
    prompt = f"""あなたは訪問鍼灸マッサージの情報共有シート作成アシスタントです。

入力された日報、患者情報、施術メモをもとに、PowerPointテンプレへ自動差し込みするためのJSONを作成してください。

出力はJSONオブジェクトのみです。
説明文、前置き、Markdown、コードブロック、```json は絶対に出さないでください。

【出力形式】
{{
  "template_type": "bodymap",
  "patient_name": "",
  "therapist_name": "担当者名",
  "created_date": "",
  "body_status": "",
  "recent_state": "",
  "notes": "",
  "shared_points": "",
  "photo_1_caption": "",
  "photo_2_caption": "",
  "sub_title_1": "",
  "sub_url_1": "",
  "main_title": "",
  "main_url": "",
  "main_qr_url": "",
  "sub_qr_url": ""
}}

【template_typeのルール】
人体図タイプ → "bodymap"
写真タイプ → "photo"
動画QRタイプ → "qr"
指定がなければ "bodymap" にしてください。

【各項目のルール】

patient_name：
・必ず空文字列（""）にする
・患者名はユーザーが手動で入力するため、AIは絶対に推測・入力しない

therapist_name：
・「担当者名」で固定
・姓と名の間は全角スペースを入れる

created_date：
・「{today}」の形式で書く
・本日の日付（{today}）で出力する

body_status：
・現在の身体状況、主な症状、施術目的をまとめる
・家族やケアマネが読んで分かりやすい表現にする
・専門用語は必ず以下のように言い換える
  （硬縮 → 関節が硬くなっている状態、
    筋の硬結 → 筋肉の凝り、
    浮腫 → むくみ、
    可動域制限 → 関節の動きが制限されている、
    筋緊張亢進 → 筋肉が張っている、
    疼痛 → 痛み、
    痺れ・痺感 → しびれ、
    歩行障害 → 歩きにくい状態、
    ADL低下 → 日常動作が難しくなっている、
    ROM制限 → 関節の動く範囲が狭くなっている）
・上記以外の専門用語も、一般の方が理解できる表現に必ず置き換える
・断定しすぎない表現にする
・診断名や医学的判断を勝手に追加しない
・目安は120〜180字

recent_state：
・最近のご様子、会話、生活状況、意欲、変化などをまとめる
・専門用語があれば body_status と同様に言い換える
・目安は100〜160字

notes：
・特別な記載がなければ以下の定型文を使う
「いつもご理解ご協力ありがとうございます。ご本人様が現状通り変わらずお元気に過ごせるよう、引き続き施術に取り組んでまいります。」

shared_points：
・介助時や日常生活で注意したい点、身体状況の共有ポイントを簡潔にまとめる
・専門用語は body_status と同様に必ず言い換える
・目安は50〜90字

photo_1_caption：
・写真1がある場合のみ、写真の説明文を作る
・写真がなければ空文字にする
・目安は20〜60字

photo_2_caption：
・写真2がある場合のみ、写真の説明文を作る
・写真がなければ空文字にする
・目安は20〜60字

main_title：
・動画QRタイプで、メイン動画の一言説明を書く
・例：「立ち上がり動作のご様子」「歩行時のご様子」「施術中の関節運動の様子」
・なければ空文字

main_url：
・動画QRタイプで、メイン動画のURLを書く
・URLが入力されていない場合は絶対に作らず、空文字

main_qr_url：
・メインQRコード生成に使うURLを書く
・通常は main_url と同じURLにする
・URLがなければ空文字

sub_qr_url：
・サブQRコード生成に使うURLを書く
・通常は sub_url_1 と同じURLにする
・URLがなければ空文字

sub_title_1：
・動画QRタイプで補助リンクがある場合のみ、短いタイトルを書く
・なければ空文字にする

sub_url_1：
・動画QRタイプで補助URLがある場合のみ、URLを書く
・URLが入力されていない場合は絶対に作らず、空文字にする

【文章ルール】
・患者、ご家族、ケアマネに見せる前提で、丁寧でやわらかい表現にする
・断定しすぎない
・診断名や医学的判断を勝手に追加しない
・入力されていない情報は推測で作らない
・住所、施設名、電話番号などの個人情報は出力しない
・文章はすべて日本語
・JSONのキー名は絶対に変更しない
・ダブルクォーテーションは必ず半角の " を使う
・末尾のカンマは付けない

【入力された日報・報告書】
{report_text}
"""

    try:
        import google.generativeai as genai
        genai.configure(api_key=GEMINI_API_KEY)
        model = genai.GenerativeModel("gemini-2.5-flash")
        response = model.generate_content(prompt)
        raw_text = response.text.strip()
    except Exception as e:
        err_str = str(e)
        if "429" in err_str or "quota" in err_str.lower():
            raise HTTPException(
                429,
                "APIの利用上限に達しました。\n"
                "現在お使いのAPIキーは無料枠が使用できない設定になっています。\n"
                "Google AI Studio（aistudio.google.com）で「新規プロジェクト」にAPIキーを作り直し、"
                ".envファイルに貼り替えてください。",
            )
        raise HTTPException(500, f"Gemini APIの呼び出しに失敗しました。\n詳細: {e}")

    # コードブロックが含まれていた場合に除去
    cleaned = raw_text.replace("```json", "").replace("```", "").strip()

    start = cleaned.find("{")
    end   = cleaned.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise HTTPException(500, f"GeminiがJSONを返しませんでした。\n出力内容: {raw_text[:200]}")

    json_str = cleaned[start:end + 1]

    try:
        parsed = _json.loads(json_str)
    except _json.JSONDecodeError as e:
        raise HTTPException(500, f"JSONの解析に失敗しました。\n詳細: {e}\n出力内容: {json_str[:200]}")

    try:
        validated = AiJsonOutput.model_validate(parsed)
    except ValidationError as e:
        raise HTTPException(422, f"AIの出力が期待する形式ではありませんでした。\n詳細: {e}")

    return {"ok": True, "data": validated.model_dump()}
