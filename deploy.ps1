# Azure Web App デプロイスクリプト
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$WebAppName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "Japan East"
)

Write-Host "Azure Web App デプロイを開始します..." -ForegroundColor Green

# Azure CLI がインストールされているかチェック
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Azure CLI がインストールされていません。インストールしてください。" -ForegroundColor Red
    exit 1
}

# ログイン確認
$account = az account show 2>$null
if (-not $account) {
    Write-Host "Azure にログインしてください..." -ForegroundColor Yellow
    az login
}

# リソースグループの作成（存在しない場合）
Write-Host "リソースグループを確認/作成中..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location

# App Service Plan の作成
Write-Host "App Service Plan を作成中..." -ForegroundColor Yellow
az appservice plan create --name "$WebAppName-plan" --resource-group $ResourceGroupName --sku B1 --is-linux

# Web App の作成
Write-Host "Web App を作成中..." -ForegroundColor Yellow
az webapp create --resource-group $ResourceGroupName --plan "$WebAppName-plan" --name $WebAppName --runtime "PYTHON|3.9"

# Python バージョンの設定
Write-Host "Python バージョンを設定中..." -ForegroundColor Yellow
az webapp config set --resource-group $ResourceGroupName --name $WebAppName --linux-fx-version "PYTHON|3.9"

# デプロイ
Write-Host "アプリケーションをデプロイ中..." -ForegroundColor Yellow
az webapp deployment source config-zip --resource-group $ResourceGroupName --name $WebAppName --src .\deploy.zip

Write-Host "デプロイが完了しました！" -ForegroundColor Green
Write-Host "Web App URL: https://$WebAppName.azurewebsites.net" -ForegroundColor Cyan
Write-Host "Bot エンドポイント: https://$WebAppName.azurewebsites.net/api/messages" -ForegroundColor Cyan 