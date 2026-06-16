"""
pdf_generator.py
送付状PDFへの担当者名差し込み、アンケートPDFのコピーを行うサービス。

使用ライブラリ:
  - reportlab : 担当者名テキストのオーバーレイPDF生成
  - pypdf     : ベースPDFへのオーバーレイ合成
"""

from __future__ import annotations

import shutil
from io import BytesIO
from pathlib import Path

# ── フォント登録（初回のみ）────────────────────────────────────────────
_FONT_NAME = "HeiseiKakuGo-W5"
_font_registered = False


def _ensure_font() -> None:
    global _font_registered
    if _font_registered:
        return
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.cidfonts import UnicodeCIDFont

    pdfmetrics.registerFont(UnicodeCIDFont(_FONT_NAME))
    _font_registered = True


# ── 送付状 PDF 生成 ───────────────────────────────────────────────────

def generate_cover_letter(
    base_pdf_path: Path,
    therapist_name: str,
    output_path: Path,
    name_x_right: float,
    name_y: float,
    font_size: int = 11,
) -> None:
    """
    送付状ひな形PDFに担当者名を差し込んで保存する。

    Parameters
    ----------
    base_pdf_path  : ひな形PDF（cover_letter_base.pdf）のパス
    therapist_name : 差し込む担当者名
    output_path    : 出力先PDFパス
    name_x_right   : テキスト右端のx座標（ポイント、ページ左下原点）
    name_y         : テキストベースラインのy座標（ポイント、ページ左下原点）
    font_size      : フォントサイズ（pt）
    """
    from reportlab.pdfgen import canvas
    from reportlab.lib.pagesizes import A4
    import pypdf

    if not base_pdf_path.exists():
        raise FileNotFoundError(
            f"送付状のひな形ファイルが見つかりません。\n"
            f"templates_documents/cover_letter_base.pdf があるか確認してください。\n"
            f"（探した場所: {base_pdf_path}）"
        )

    _ensure_font()

    # ─ 担当者名テキストのオーバーレイ PDF を BytesIO に生成 ─
    buf = BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)
    c.setFont(_FONT_NAME, font_size)
    c.setFillColorRGB(0, 0, 0)          # 黒文字
    c.drawRightString(name_x_right, name_y, therapist_name)
    c.save()
    buf.seek(0)

    # ─ ベースPDFにオーバーレイを合成 ─
    reader = pypdf.PdfReader(str(base_pdf_path))
    overlay_reader = pypdf.PdfReader(buf)

    writer = pypdf.PdfWriter()
    page = reader.pages[0]
    page.merge_page(overlay_reader.pages[0])
    writer.add_page(page)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "wb") as f:
        writer.write(f)


# ── アンケート PDF コピー ─────────────────────────────────────────────

def copy_survey(
    survey_pdf_path: Path,
    output_path: Path,
) -> None:
    """
    アンケートPDFをコピーして保存する（編集不要のためそのままコピー）。

    Parameters
    ----------
    survey_pdf_path : コピー元のアンケートPDF（family_survey_first.pdf 等）
    output_path     : コピー先のパス
    """
    if not survey_pdf_path.exists():
        raise FileNotFoundError(
            f"アンケートのひな形ファイルが見つかりません。\n"
            f"templates_documents/ に {survey_pdf_path.name} があるか確認してください。\n"
            f"（探した場所: {survey_pdf_path}）"
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(str(survey_pdf_path), str(output_path))
