# Azure Bot Service 作成スクリプト
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$BotName,
    
    [Parameter(Mandatory=$true)]
    [string]$WebAppUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "Japan East"
)

Write-Host "Azure Bot Service を作成します..." -ForegroundColor Green

# Azure CLI がインストールされているかチェック
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Azure CLI がインストールされていません。" -ForegroundColor Red
    exit 1
}

# ログイン確認
$account = az account show 2>$null
if (-not $account) {
    Write-Host "Azure にログインしてください..." -ForegroundColor Yellow
    az login
}

# Bot Service 作成
Write-Host "Bot Service を作成中..." -ForegroundColor Yellow
az bot create --resource-group $ResourceGroupName --name $BotName --kind webapp --location $Location

# Bot エンドポイント設定
Write-Host "Bot エンドポイントを設定中..." -ForegroundColor Yellow
az bot webchat create --name $BotName --resource-group $ResourceGroupName

# Messaging エンドポイント設定
Write-Host "Messaging エンドポイントを設定中..." -ForegroundColor Yellow
az bot update --name $BotName --resource-group $ResourceGroupName --endpoint "$WebAppUrl/api/messages"

# Teams チャンネル追加
Write-Host "Teams チャンネルを追加中..." -ForegroundColor Yellow
az bot msteams create --name $BotName --resource-group $ResourceGroupName

Write-Host "Bot Service 作成が完了しました！" -ForegroundColor Green
Write-Host "Bot 管理ページ: https://portal.azure.com/#@/resource/subscriptions/*/resourceGroups/$ResourceGroupName/providers/Microsoft.BotService/botServices/$BotName" -ForegroundColor Cyan
Write-Host "Teams で使用するには、Bot 管理ページからTeamsチャンネルを設定してください。" -ForegroundColor Cyan 