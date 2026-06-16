"""
webview_launcher.py
uvicornをバックグラウンドスレッドで起動し、
pywebviewの専用ウィンドウでアプリを表示する。
"""

import socket
import threading
import time
import urllib.request
import urllib.error
import signal
import sys
from pathlib import Path

import uvicorn
import webview

# ── 設定 ──────────────────────────────────────────────────────────
HOST = "127.0.0.1"


def _find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((HOST, 0))
        return s.getsockname()[1]


PORT = _find_free_port()
URL  = f"http://{HOST}:{PORT}"
TITLE = "情報共有シートDX"

WINDOW_WIDTH  = 1000
WINDOW_HEIGHT = 800
RESIZABLE     = False


# ── uvicorn をスレッドで起動 ───────────────────────────────────────
def start_server():
    config = uvicorn.Config(
        "app.main:app",
        host=HOST,
        port=PORT,
        log_level="warning",
    )
    server = uvicorn.Server(config)
    server.run()


def wait_for_server(timeout: int = 10) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            urllib.request.urlopen(URL, timeout=1)
            return True
        except Exception:
            time.sleep(0.3)
    return False


# ── Dock アイコン設定 & 再オープンハンドラ ────────────────────────
def _setup_dock():
    """
    Platypus は LSUIElement=true で Dock から非表示にしてある。
    Python/pywebview が Dock アイコンを管理する（Regular ポリシーのまま）。

    ① アイコン：.app バンドル内の AppIcon.icns をセット
    ② Dock クリック時：ウィンドウが最小化されていれば復元して前面に出す
       （ウィンドウが表示中の場合は macOS が自動で前面に出してくれる）

    func= コールバックは start() 後に別スレッドで実行される。
    """
    time.sleep(0.5)  # pywebview の NSApplication 初期化完了を待つ
    try:
        import AppKit

        # ① カスタムアイコンを設定
        # __file__ = .../Contents/Resources/_システム用_触らない/webview_launcher.py
        icon_path = Path(__file__).parent.parent / "AppIcon.icns"
        if icon_path.exists():
            image = AppKit.NSImage.alloc().initWithContentsOfFile_(str(icon_path))
            if image:
                AppKit.NSApplication.sharedApplication().setApplicationIconImage_(image)

        # ② Dock クリック時（再オープン）のハンドラを既存デリゲートに追加
        import objc

        def _reopen(self, app, hasVisibleWindows):
            """ウィンドウが最小化 or 非表示の場合に復元して前面に出す"""
            if not hasVisibleWindows:
                for w in webview.windows:
                    try:
                        w.restore()
                    except Exception:
                        pass
            AppKit.NSApplication.sharedApplication().activateIgnoringOtherApps_(True)
            return True

        ns_app = AppKit.NSApplication.sharedApplication()
        delegate = ns_app.delegate()
        if delegate is not None:
            # 既存デリゲートクラスにメソッドを追加（上書きでなく追加のみ）
            delegate_cls = type(delegate)
            method_sel = b"applicationShouldHandleReopen:hasVisibleWindows:"
            if not objc.lookUpClass(delegate_cls.__name__).instancesRespondToSelector_(method_sel):
                objc.classAddMethods(delegate_cls, [_reopen])
    except Exception:
        pass


# ── Finder から二重起動された場合の SIGUSR1 ハンドラ ──────────────
def _setup_reopen_handler():
    """
    .app が Finder から二重起動されると launch_for_platypus.sh が再実行され、
    ポート競合検知後に SIGUSR1 が送られる。
    受信したらウィンドウを前面に出す。
    signal.signal は main thread からのみ呼べるため webview.start() 前に呼ぶこと。
    """
    def _on_sigusr1(signum, frame):
        try:
            from Foundation import NSRunLoop

            def _activate():
                try:
                    import AppKit
                    AppKit.NSApplication.sharedApplication().activateIgnoringOtherApps_(True)
                    for w in webview.windows:
                        try:
                            w.restore()
                        except Exception:
                            pass
                except Exception:
                    pass

            NSRunLoop.mainRunLoop().performBlock_(_activate)
        except Exception:
            try:
                import AppKit
                AppKit.NSApplication.sharedApplication().activateIgnoringOtherApps_(True)
            except Exception:
                pass

    try:
        signal.signal(signal.SIGUSR1, _on_sigusr1)
    except Exception:
        pass


# ── メイン ────────────────────────────────────────────────────────
def main():
    # Dock クリック時の SIGUSR1 ハンドラを main thread で登録（webview.start() 前に必須）
    _setup_reopen_handler()

    server_thread = threading.Thread(target=start_server, daemon=True)
    server_thread.start()

    if not wait_for_server(timeout=10):
        window = webview.create_window(
            TITLE,
            html="<h2 style='font-family:sans-serif;color:red;padding:40px'>アプリの起動に失敗しました。<br>もう一度起動してください。</h2>",
            width=500,
            height=300,
        )
        webview.start()
        sys.exit(1)

    window = webview.create_window(
        TITLE,
        url=URL,
        width=WINDOW_WIDTH,
        height=WINDOW_HEIGHT,
        resizable=RESIZABLE,
        text_select=True,
        zoomable=False,
        confirm_close=False,
    )

    # func= に渡すことで webview.start() の NSApplication 初期化後に実行させる
    webview.start(func=_setup_dock)


if __name__ == "__main__":
    import os
    os.chdir(Path(__file__).parent)
    main()
