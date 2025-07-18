import os
from aiohttp import web
from botbuilder.core import BotFrameworkAdapterSettings, TurnContext, ActivityHandler
from botbuilder.schema import Activity
from botbuilder.integration.aiohttp import BotFrameworkHttpAdapter
from dotenv import load_dotenv

# .envファイルを読み込み
load_dotenv()

# Adapter設定 (User Assigned Managed Identity使用)
APP_ID = os.getenv("MicrosoftAppId", "")
# User Assigned Managed Identity使用時はAppPassword不要
SETTINGS = BotFrameworkAdapterSettings(APP_ID, "")
ADAPTER = BotFrameworkHttpAdapter(SETTINGS)

# エラーハンドラー
async def on_error(context: TurnContext, error: Exception):
    print(f"[on_turn_error]: {error}")
    await context.send_activity("エラーが発生しました。もう一度お試しください。")
ADAPTER.on_turn_error = on_error

# エコーBot
class EchoBot(ActivityHandler):
    async def on_message_activity(self, turn_context: TurnContext):
        await turn_context.send_activity(f"Echo: {turn_context.activity.text}")
    async def on_members_added_activity(self, members_added, turn_context: TurnContext):
        for member in members_added:
            if member.id != turn_context.activity.recipient.id:
                await turn_context.send_activity("こんにちは！エコーBotです。メッセージを送ってみてください。")

BOT = EchoBot()

# メッセージエンドポイント
async def messages(req: web.Request) -> web.Response:
    body = await req.json()
    activity = Activity().deserialize(body)
    auth_header = req.headers.get("Authorization", "")
    response = await ADAPTER.process_activity(activity, auth_header, BOT.on_turn)
    if response:
        return web.json_response(data=response.body, status=response.status)
    return web.Response(status=201)

# アプリケーション設定
APP = web.Application()
APP.router.add_post("/api/messages", messages)

# ヘルスチェック
async def health(req):
    return web.Response(text="Bot is running!", status=200)
APP.router.add_get("/health", health)

# ルートページ（テスト用）
async def root(req):
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Teams Echo Bot</title>
        <meta charset="utf-8">
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }
            .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            h1 { color: #0078d4; text-align: center; }
            .endpoint { background: #f8f9fa; padding: 15px; margin: 10px 0; border-radius: 5px; border-left: 4px solid #0078d4; }
            .method { font-weight: bold; color: #0078d4; }
            .url { font-family: monospace; background: #e9ecef; padding: 2px 6px; border-radius: 3px; }
            .status { color: #28a745; font-weight: bold; }
            .error { color: #dc3545; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🤖 Teams Echo Bot</h1>
            <p>このページは、Teams Echo Botのテスト用ページです。</p>
            
            <h2>📋 利用可能なエンドポイント</h2>
            
            <div class="endpoint">
                <div class="method">GET</div>
                <div class="url">/</div>
                <div>このページを表示（現在のページ）</div>
            </div>
            
            <div class="endpoint">
                <div class="method">GET</div>
                <div class="url">/health</div>
                <div>Botの動作状況を確認</div>
            </div>
            
            <div class="endpoint">
                <div class="method">POST</div>
                <div class="url">/api/messages</div>
                <div>Bot Frameworkメッセージエンドポイント</div>
            </div>
            
            <h2>🧪 テスト方法</h2>
            <p>以下のリンクで各エンドポイントをテストできます：</p>
            <ul>
                <li><a href="/health" target="_blank">ヘルスチェック</a></li>
                <li><a href="/api/messages" target="_blank">Bot エンドポイント（404エラーが正常）</a></li>
            </ul>
            
            <h2>📊 ステータス</h2>
            <p><span class="status">✅ Bot は正常に動作しています</span></p>
            <p>Web App URL: <span class="url">https://teams-echo-bot.azurewebsites.net</span></p>
            <p>Bot エンドポイント: <span class="url">https://teams-echo-bot.azurewebsites.net/api/messages</span></p>
        </div>
    </body>
    </html>
    """
    return web.Response(text=html_content, content_type='text/html')
APP.router.add_get("/", root)

if __name__ == "__main__":
    host = os.getenv("HOST", "0.0.0.0")  # Azure Web Appsでは0.0.0.0を使用
    port = int(os.getenv("PORT", 8000))  # Azure Web Appsのデフォルトポート
    print(f"Bot Emulator用のエコーBotを起動しています... http://{host}:{port}/api/messages")
    web.run_app(APP, host=host, port=port) 