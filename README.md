# Teams Echo Bot - Python

Microsoft Teams向けのエコーBotです。Bot Framework Emulatorでローカルテストができ、Azure Web Appにデプロイ可能です。

## 機能

- ユーザーのメッセージをエコーで返す
- Bot Framework Emulator対応
- Azure Web Appデプロイ対応
- Teams連携準備済み

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

### 方法1: Azure CLI を使用

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

3. **デプロイスクリプト実行**
   ```powershell
   .\deploy.ps1 -ResourceGroupName "my-bot-rg" -WebAppName "my-echo-bot"
   ```

### 方法2: Azure Portal を使用

1. **Azure Portal**で新しいWeb Appを作成
2. **Python 3.9**ランタイムを選択
3. **デプロイセンター**からGitHub連携またはZIPデプロイ

### 方法3: GitHub Actions を使用

`.github/workflows/deploy.yml`を作成して自動デプロイを設定できます。

## Bot Framework Emulator 設定

1. [Bot Framework Emulator](https://github.com/Microsoft/BotFramework-Emulator/releases)をダウンロード
2. 接続設定:
   - **Bot URL**: `http://localhost:3978/api/messages` (ローカル) または `https://your-app.azurewebsites.net/api/messages` (Azure)
   - **Microsoft App ID**: 空欄
   - **Microsoft App Password**: 空欄

## Teams 連携

1. **Azure Bot Service**でBotを登録
2. **Teams チャンネル**を追加
3. **Bot エンドポイント**をAzure Web AppのURLに設定

## ファイル構成

```
teams-bot-python/
├── app.py                 # メインBotアプリケーション
├── requirements.txt       # Python依存関係
├── web.config            # Azure Web App設定
├── runtime.txt           # Pythonバージョン指定
├── deploy.ps1            # デプロイスクリプト
├── .gitignore            # Git除外設定
└── README.md             # このファイル
```

## トラブルシューティング

### ローカル実行エラー
- 仮想環境がアクティベートされているか確認
- 依存関係が正しくインストールされているか確認

### Azure デプロイエラー
- Python 3.9がサポートされているか確認
- `web.config`の設定を確認
- Azure CLIが最新版か確認

## 次のステップ

- [ ] Azure Boards連携機能追加
- [ ] より高度な会話機能実装
- [ ] 認証機能追加
- [ ] ログ機能強化 