#!/bin/bash
# 情報共有シートDX — エンジニア用起動スクリプト
# ※ 社員の方はルートの「アプリを起動する.command」を使ってください

# ─── パス設定 ───────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYSTEM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"     # _システム用_触らない/
VENV_PYTHON="$SYSTEM_DIR/.venv/bin/python"
PORT=8000

# ─── 見出し ─────────────────────────────────────────────────
clear
echo "========================================"
echo "  情報共有シートDX  起動します"
echo "========================================"
echo ""

# ─── 仮想環境チェック ────────────────────────────────────────
if [ ! -f "$VENV_PYTHON" ]; then
  echo "【エラー】Pythonの仮想環境が見つかりません。"
  echo ""
  echo "  まずルートフォルダの「アプリを起動する.command」を実行してください。"
  echo "  （自動でセットアップされます）"
  echo ""
  read -p "Enterキーで閉じます..."
  exit 1
fi

# ─── ポート使用中チェック ─────────────────────────────────────
EXISTING_PID=$(lsof -i :"$PORT" -sTCP:LISTEN -t 2>/dev/null)
if [ -n "$EXISTING_PID" ]; then
  PROC_CMD=$(ps -p "$EXISTING_PID" -o args= 2>/dev/null)
  if echo "$PROC_CMD" | grep -qE "uvicorn|app\.main"; then
    echo "前回のアプリが起動したままでした。自動で終了します..."
    kill "$EXISTING_PID" 2>/dev/null
    sleep 2
    if lsof -i :"$PORT" -sTCP:LISTEN -t > /dev/null 2>&1; then
      kill -9 "$EXISTING_PID" 2>/dev/null
      sleep 1
    fi
    echo "終了しました。起動を続けます。"
    echo ""
  else
    PROC_NAME=$(ps -p "$EXISTING_PID" -o comm= 2>/dev/null)
    echo "【エラー】ポート $PORT が別のアプリで使われています。"
    echo "（使用中: ${PROC_NAME:-不明}）"
    echo "そのアプリを終了してから、もう一度起動してください。"
    echo ""
    read -p "Enterキーで閉じます..."
    exit 1
  fi
fi

# ─── 起動メッセージ ──────────────────────────────────────────
echo "========================================"
echo "AIアシストDXツールを起動しています"
echo "アプリ名：情報共有シートDX"
echo "URL：http://127.0.0.1:$PORT"
echo "終了方法：control + C"
echo "========================================"

# ─── 1.5秒後にブラウザを自動で開く ──────────────────────────
(sleep 1.5 && open "http://localhost:$PORT") &

# ─── サーバー起動 ────────────────────────────────────────────
cd "$SYSTEM_DIR"
"$VENV_PYTHON" -m uvicorn app.main:app --host 127.0.0.1 --port "$PORT"

echo ""
echo "アプリを終了しました。"
echo "この画面は閉じてOKです。"
read -p "Enterキーで閉じます..."
