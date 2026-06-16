#!/bin/bash
# 情報共有シートDX — 配布前準備スクリプト
# 他社員へ渡す前に、不要ファイルを除いたZIPを作成します

# ─── パス設定 ───────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYSTEM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"   # _システム用_触らない/
ROOT_DIR="$(cd "$SYSTEM_DIR/.." && pwd)"     # アプリのルートフォルダ（名前が変わっても自動追従）
APP_NAME="$(basename "$ROOT_DIR")"
DATE=$(date +%Y%m%d)
ZIP_NAME="情報共有シートDX_配布用_${DATE}.zip"
OUTPUT_ZIP="$HOME/Documents/$ZIP_NAME"
TEMP_DIR="$(mktemp -d)"
TEMP_APP="$TEMP_DIR/$APP_NAME"

clear
echo "========================================"
echo "  情報共有シートDX  配布前準備"
echo "========================================"
echo ""
echo "このスクリプトは、他社員へ渡す用のZIPを作成します。"
echo ""
echo "  除外されるもの："
echo "    ・_システム用_触らない/.venv（仮想環境）"
echo "    ・完成ファイル/ のPPTX・PDFファイル（患者情報）"
echo "    ・_システム用_触らない/work/uploads/ の中身"
echo "    ・_システム用_触らない/work/temp/ の中身"
echo "    ・__pycache__、.DS_Store などの不要ファイル"
echo ""
echo "  作成されるZIP："
echo "    $OUTPUT_ZIP"
echo ""

# ─── 既存ZIPの確認 ──────────────────────────────────────────
if [ -f "$OUTPUT_ZIP" ]; then
  echo "【確認】同じ名前のZIPがすでに存在します："
  echo "  $OUTPUT_ZIP"
  echo ""
  read -p "上書きしますか？ (y / Enterでキャンセル): " OVERWRITE
  if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
    echo ""
    echo "キャンセルしました。"
    read -p "Enterキーで閉じます..."
    rm -rf "$TEMP_DIR"
    exit 0
  fi
  echo ""
fi

# ─── ファイルのコピー ─────────────────────────────────────
echo "[1/3] ファイルをコピーしています..."
echo "  （患者情報・仮想環境を除外します）"
echo ""

rsync -a \
  --exclude='_システム用_触らない/.venv/' \
  --exclude='_システム用_触らない/.venv_退避_*/' \
  --exclude='完成ファイル/*.pptx' \
  --exclude='完成ファイル/*.pdf' \
  --exclude='_システム用_触らない/work/uploads/' \
  --exclude='_システム用_触らない/work/temp/' \
  --exclude='__pycache__/' \
  --exclude='.DS_Store' \
  --exclude='*.pyc' \
  --exclude='~$*' \
  "$ROOT_DIR/" "$TEMP_APP/"

if [ $? -ne 0 ]; then
  echo "  【エラー】ファイルのコピーに失敗しました。"
  rm -rf "$TEMP_DIR"
  read -p "Enterキーで閉じます..."
  exit 1
fi

# ─── 空フォルダを再作成（.gitkeepで中身を保持） ─────────────
mkdir -p "$TEMP_APP/完成ファイル"
mkdir -p "$TEMP_APP/_システム用_触らない/work/uploads"
mkdir -p "$TEMP_APP/_システム用_触らない/work/temp"

touch "$TEMP_APP/完成ファイル/.gitkeep"
touch "$TEMP_APP/_システム用_触らない/work/uploads/.gitkeep"
touch "$TEMP_APP/_システム用_触らない/work/temp/.gitkeep"

# ─── アプリを起動する.command に実行権限を付与 ──────────────
chmod +x "$TEMP_APP/アプリを起動する.command" 2>/dev/null

echo "  OK: コピー完了"
echo ""

# ─── ZIP作成 ─────────────────────────────────────────────
echo "[2/3] ZIPファイルを作成しています..."
echo "  保存先: $OUTPUT_ZIP"
echo ""

ditto -c -k --keepParent "$TEMP_APP" "$OUTPUT_ZIP"

if [ $? -ne 0 ]; then
  echo "  【エラー】ZIPの作成に失敗しました。"
  rm -rf "$TEMP_DIR"
  read -p "Enterキーで閉じます..."
  exit 1
fi

echo "  OK: ZIP作成完了"
echo ""

# ─── 一時フォルダを削除 ──────────────────────────────────────
echo "[3/3] 一時ファイルを削除しています..."
rm -rf "$TEMP_DIR"
echo "  OK: 完了"
echo ""

# ─── 結果表示 ────────────────────────────────────────────────
ZIP_SIZE=$(du -sh "$OUTPUT_ZIP" 2>/dev/null | cut -f1)
echo "========================================"
echo "  ZIP作成完了！"
echo "========================================"
echo ""
echo "  ファイル名 : $ZIP_NAME"
echo "  サイズ     : $ZIP_SIZE"
echo "  保存先     : $HOME/Documents/"
echo ""
echo "【渡す前に確認してください】"
echo "  ・完成ファイル/ にPPTX・PDFが含まれていないか"
echo "  ・_システム用_触らない/pptx_templates/ に3つのテンプレがあるか"
echo "  ・_システム用_触らない/templates_documents/ に書類テンプレがあるか"
echo ""
echo "【受け取った側の操作手順】"
echo "  1. ZIPを解凍する"
echo "  2. フォルダを好きな場所に置く"
echo "  3. 「アプリを起動する.command」をダブルクリックする"
echo "     → 初回のみ自動でセットアップ（1〜3分）"
echo "     → 以降はブラウザで操作するだけ"
echo ""

# ─── Finderで開く ────────────────────────────────────────────
read -p "FinderでZIPの場所を開きますか？ (y / Enterでスキップ): " OPEN_FINDER
if [ "$OPEN_FINDER" = "y" ] || [ "$OPEN_FINDER" = "Y" ]; then
  open -R "$OUTPUT_ZIP"
fi

echo ""
read -p "Enterキーで閉じます..."
