# Teams Echo Bot - Python

Microsoft Teams向けのエコーBotです。Bot Framework Emulatorでローカルテストができ、Azure Web Appにデプロイ可能です。

## 機能

- ユーザーのメッセージをエコーで返す
- Bot Framework Emulator対応
- Azure Web Appデプロイ対応
- Teams連携準備済み
- User Assigned Managed Identity対応（AppPassword不要）

## 開発履歴と試行錯誤

### 2025-07-11: 初期開発
- ✅ Bot Framework SDK v4を使用したエコーBot作成
- ✅ ローカルでのBot Emulator動作確認
- ✅ 基本的なファイル構成の設定

### 2025-07-11: Azure Web Appデプロイの試行錯誤

#### 問題1: Bot Service作成エラー
```
the following arguments are required: --appid, --app-type
```
**解決**: `az bot create`コマンドに必須パラメータを追加
- `--appid`: Azure ADアプリケーションID
- `--app-type`: アプリケーションタイプ

#### 問題2: デプロイコマンドの非推奨警告
```
This command has been deprecated and will be removed in a future release.
```
**解決**: `az webapp deployment source config-zip` → `az webapp deploy`に変更

#### 問題3: Python環境の不一致
```
runtime.txt: python-3.9
Web App: PYTHON:3.11
```
**解決**: `runtime.txt`を`python-3.11`に修正

#### 問題4: Oryxの自動検出問題
```
Detected an app based on Flask
Generating `gunicorn` command for 'app:app'
ModuleNotFoundError: No module named 'aiohttp'
```
**原因**: OryxがaiohttpアプリをFlaskアプリとして誤認識
**解決**: アプリケーション設定で以下を追加
```powershell
ENABLE_ORYX_BUILD=false
STARTUP_COMMAND="python3 -m pip install -r requirements.txt && python3 app.py"
```

#### 問題5: 仮想環境の問題
```
The virtual environment was not created successfully because ensurepip is not available
```
**解決**: `startup.txt`を使用してシステム全体に依存関係をインストール

### 最終的な解決方法

#### 1. アプリケーション設定
```powershell
az webapp config appsettings set --resource-group $ResourceGroupName --name $WebAppName --settings `
    SCM_DO_BUILD_DURING_DEPLOYMENT=true `
    ENABLE_ORYX_BUILD=false `
    PYTHON_VERSION=3.11 `
    STARTUP_COMMAND="python3 -m pip install -r requirements.txt && python3 app.py"
```

#### 2. ファイル構成
```
teams-bot-python/
├── app.py                 # メインBotアプリケーション
├── requirements.txt       # Python依存関係
├── runtime.txt           # Python 3.11指定
├── startup.txt           # カスタム起動コマンド
├── deploy.ps1            # デプロイスクリプト
└── README.md             # このファイル
```

#### 3. 成功のポイント
- ✅ Oryxの自動検出を無効化
- ✅ カスタム起動コマンドで依存関係を事前インストール
- ✅ Python 3.11の明示的指定
- ✅ User Assigned Managed Identity使用

## ローカル開発

### 1. 環境セットアップ

```bash
# 仮想環境作成
python -m venv venv

# 仮想環境アクティベート
# Windows
venv\Scripts\activate
# macOS/Linux
source venv/bin/activate

# 依存関係インストール
pip install -r requirements.txt
```

### 2. ローカル実行

```bash
python app.py
```

Bot Emulatorで `http://localhost:3978/api/messages` に接続してテストできます。

## Azure Web App デプロイ

### 自動デプロイ（推奨）

```powershell
# デプロイスクリプト実行
.\deploy.ps1

# または、パラメータを指定
.\deploy.ps1 -ResourceGroupName "my-bot-rg" -WebAppName "my-echo-bot" -Location "japanwest"
```

### 手動デプロイ

1. **Azure CLI インストール**
   ```bash
   # Windows
   winget install Microsoft.AzureCLI
   # macOS
   brew install azure-cli
   ```

2. **ログイン**
   ```bash
   az login
   ```

3. **リソース作成とデプロイ**
   ```bash
   # リソースグループ作成
   az group create --name my-bot-rg --location japanwest
   
   # App Service Plan作成
   az appservice plan create --name my-bot-plan --resource-group my-bot-rg --sku B1 --is-linux
   
   # Web App作成
   az webapp create --resource-group my-bot-rg --plan my-bot-plan --name my-echo-bot --runtime "PYTHON|3.11"
   
   # アプリケーション設定
   az webapp config appsettings set --resource-group my-bot-rg --name my-echo-bot --settings `
       SCM_DO_BUILD_DURING_DEPLOYMENT=true `
       ENABLE_ORYX_BUILD=false `
       PYTHON_VERSION=3.11 `
       STARTUP_COMMAND="python3 -m pip install -r requirements.txt && python3 app.py"
   
   # デプロイ
   az webapp deploy --resource-group my-bot-rg --name my-echo-bot --src-path .\deploy.zip --type zip
   ```

## Bot Framework Emulator 設定

1. [Bot Framework Emulator](https://github.com/Microsoft/BotFramework-Emulator/releases)をダウンロード
2. 接続設定:
   - **Bot URL**: `http://localhost:3978/api/messages` (ローカル) または `https://your-app.azurewebsites.net/api/messages` (Azure)
   - **Microsoft App ID**: 空欄（User Assigned Managed Identity使用）
   - **Microsoft App Password**: 空欄

## Teams 連携

1. **Azure Bot Service**でBotを登録（deploy.ps1で自動作成）
2. **Teams チャンネル**を手動で追加
3. **Bot エンドポイント**は自動設定済み

## 利用可能なエンドポイント

- **GET** `/` - テスト用ホームページ
- **GET** `/health` - ヘルスチェック
- **POST** `/api/messages` - Bot Frameworkメッセージエンドポイント

## トラブルシューティング

### よくある問題

#### 1. 404エラー
- `/api/messages`へのGETリクエストは404が正常（POSTのみ対応）
- `/health`でBotの動作確認

#### 2. 依存関係エラー
- `startup.txt`が正しく配置されているか確認
- アプリケーション設定の`STARTUP_COMMAND`を確認

#### 3. Oryxの誤認識
- `ENABLE_ORYX_BUILD=false`が設定されているか確認
- `startup.txt`が存在するか確認

## 次のステップ

- [ ] Azure Boards連携機能追加
- [ ] より高度な会話機能実装
- [ ] 認証機能追加
- [ ] ログ機能強化
- [ ] CI/CDパイプライン構築 