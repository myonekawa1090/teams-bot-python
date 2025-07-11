import os
from aiohttp import web
from botbuilder.core import BotFrameworkAdapterSettings, TurnContext, ActivityHandler
from botbuilder.schema import Activity
from botbuilder.integration.aiohttp import BotFrameworkHttpAdapter

# Adapter設定
APP_ID = os.environ.get("MicrosoftAppId", "")
APP_PASSWORD = os.environ.get("MicrosoftAppPassword", "")
SETTINGS = BotFrameworkAdapterSettings(APP_ID, APP_PASSWORD)
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

if __name__ == "__main__":
    print("Bot Emulator用のエコーBotを起動しています... http://localhost:3978/api/messages")
    web.run_app(APP, host="localhost", port=3978) 