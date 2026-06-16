import os
from pathlib import Path
from dotenv import load_dotenv

# .env ファイルを読み込む（_システム用_触らない/ 直下）
load_dotenv(Path(__file__).parent.parent / ".env")

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")

# _システム用_触らない/ 自身のディレクトリ
BASE_DIR = Path(__file__).parent.parent

# アプリのルートフォルダ（フォルダ名・場所が変わっても自動追従）
ROOT_DIR = BASE_DIR.parent

PPTX_TEMPLATES_DIR = BASE_DIR / "pptx_templates"
DOCS_TEMPLATES_DIR = BASE_DIR / "templates_documents"
WORK_DIR = BASE_DIR / "work"
UPLOAD_DIR = WORK_DIR / "uploads"
TEMP_DIR = WORK_DIR / "temp"

# 完成ファイルの保存先
# JOSHO_OUTPUT_DIR が設定されている場合はそちらを優先（.appバンドル対応）
# 未設定の場合はルートの「完成ファイル」フォルダ（.command直接起動との後方互換）
_output_dir_env = os.environ.get("JOSHO_OUTPUT_DIR")
OUTPUT_DIR = Path(_output_dir_env) if _output_dir_env else ROOT_DIR / "完成ファイル"

TEMPLATE_MAP = {
    "bodymap": PPTX_TEMPLATES_DIR / "template_bodymap.pptx",
    "photo": PPTX_TEMPLATES_DIR / "template_photo.pptx",
    "qr": PPTX_TEMPLATES_DIR / "template_qr.pptx",
}

DEFAULT_THERAPIST_NAME = "野間 一輝"
DEFAULT_NOTES = (
    "いつもご理解ご協力ありがとうございます。"
    "ご本人様が現状通り変わらずお元気に過ごせるよう、引き続き施術に取り組んでまいります。"
)

# ── 送付状 PDF への担当者名差し込み位置 ──────────────────────────────
# cover_letter_base.pdf の「からだアシスト」（y0=743.3）の1行下・右揃え
# 調整が必要な場合はここの数値を変更してください（単位：ポイント、ページ左下原点）
COVER_LETTER_NAME_X_RIGHT = 524.0   # 担当者名テキストの右端 x 座標
COVER_LETTER_NAME_Y      = 723.0   # 担当者名テキストのベースライン y 座標
COVER_LETTER_NAME_FONT_SIZE = 11    # フォントサイズ（pt）
