import re


def safe_filename(text: str) -> str:
    text = str(text or "no_name").strip()
    text = text.replace("　", "").replace(" ", "")
    text = re.sub(r'[\\/:*?"<>|]', "_", text)
    return text or "no_name"
