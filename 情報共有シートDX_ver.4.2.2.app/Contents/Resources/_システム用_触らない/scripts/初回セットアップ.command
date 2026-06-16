#!/bin/bash
# 情報共有シートDX — 初回セットアップスクリプト
# 初めて使うときだけ実行してください（2回目以降は不要です）

# ─── パス設定 ───────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"    # _システム用_触らない/
VENV_DIR="$APP_DIR/.venv"
REQ_FILE="$APP_DIR/requirements.txt"

clear
echo "========================================"
echo "  情報共有シートDX  初回セットアップ"
echo "========================================"
echo ""

# ─── スクリプトの実行権限を先に修正（コピー時に失われる場合がある）─
echo "[0/5] スクリプトの実行権限を確認しています..."
chmod +x "$SCRIPT_DIR"/*.command 2>/dev/null && \
  echo "  OK: 実行権限を設定しました" || \
  echo "  （権限の設定をスキップしました）"
echo ""

# ─── Python確認 ──────────────────────────────────────────────
echo "[1/5] Pythonを確認しています..."
if command -v python3 > /dev/null 2>&1; then
  PY_VER=$(python3 --version 2>&1)
  echo "  OK: $PY_VER"
else
  echo "  【エラー】Python3が見つかりません。"
  echo "  Python3をインストールしてから再度実行してください。"
  read -p "Enterキーで閉じます..."
  exit 1
fi
echo ""

# ─── 仮想環境の準備 ──────────────────────────────────────────
echo "[2/5] Pythonの仮想環境を確認しています..."
if [ -d "$VENV_DIR" ]; then
  echo "  仮想環境がすでにあります: $VENV_DIR"
else
  echo "  仮想環境を作成します..."
  python3 -m venv "$VENV_DIR"
  if [ $? -ne 0 ]; then
    echo "  【エラー】仮想環境の作成に失敗しました。"
    read -p "Enterキーで閉じます..."
    exit 1
  fi
  echo "  OK: 仮想環境を作成しました"
fi
echo ""

# ─── ライブラリのインストール ─────────────────────────────────
echo "[3/5] 必要なライブラリをインストールしています..."
echo "  （時間がかかる場合があります。しばらくお待ちください）"
echo ""
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet -r "$REQ_FILE"
if [ $? -ne 0 ]; then
  echo ""
  echo "  【エラー】ライブラリのインストールに失敗しました。"
  echo "  インターネット接続を確認してから再度実行してください。"
  read -p "Enterキーで閉じます..."
  exit 1
fi
echo "  OK: ライブラリをインストールしました"
echo ""

# ─── テンプレートファイル確認 ─────────────────────────────────
echo "[5/5] PowerPointテンプレートを確認しています..."
TMPL_DIR="$APP_DIR/pptx_templates"
MISSING=0
for f in template_bodymap.pptx template_photo.pptx template_qr.pptx; do
  if [ -f "$TMPL_DIR/$f" ]; then
    echo "  OK: $f"
  else
    echo "  【不足】$f が見つかりません"
    MISSING=1
  fi
done

if [ $MISSING -eq 1 ]; then
  echo ""
  echo "  PPTXテンプレートが不足しています。"
  echo "  $TMPL_DIR に以下のファイルをコピーしてください："
  echo "    template_bodymap.pptx"
  echo "    template_photo.pptx"
  echo "    template_qr.pptx"
  echo ""
  read -p "Enterキーで閉じます..."
  exit 1
fi
echo ""

# ─── 完了 ────────────────────────────────────────────────────
echo "========================================"
echo "  セットアップ完了！"
echo "========================================"
echo ""
echo "次回から「アプリを起動する.command」をダブルクリックするだけで"
echo "情報共有シートDX が起動します。"
echo ""
echo "  ※ 「アプリを起動する.command」は1つ上のフォルダにあります"
echo ""
read -p "Enterキーで閉じます..."
