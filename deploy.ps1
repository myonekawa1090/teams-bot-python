# Azure Web App デプロイスクリプト
param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$WebAppName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location
)

# .envファイルから環境変数を読み込み
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]+)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

# パラメータが指定されていない場合は環境変数から取得
if (-not $ResourceGroupName) {
    $ResourceGroupName = [Environment]::GetEnvironmentVariable("AZURE_RESOURCE_GROUP", "Process")
    if (-not $ResourceGroupName) {
        Write-Host "エラー: ResourceGroupNameが指定されていません。.envファイルまたはパラメータで指定してください。" -ForegroundColor Red
        exit 1
    }
}

if (-not $WebAppName) {
    $WebAppName = [Environment]::GetEnvironmentVariable("AZURE_WEBAPP_NAME", "Process")
    if (-not $WebAppName) {
        Write-Host "エラー: WebAppNameが指定されていません。.envファイルまたはパラメータで指定してください。" -ForegroundColor Red
        exit 1
    }
}

if (-not $Location) {
    $Location = [Environment]::GetEnvironmentVariable("AZURE_LOCATION", "Process")
    if (-not $Location) {
        $Location = "japanwest"
    }
}

Write-Host "Azure Web App デプロイを開始します..." -ForegroundColor Green
Write-Host "リソースグループ: $ResourceGroupName" -ForegroundColor Cyan
Write-Host "Web App名: $WebAppName" -ForegroundColor Cyan
Write-Host "ロケーション: $Location" -ForegroundColor Cyan
Write-Host ""

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
az webapp create --resource-group $ResourceGroupName --plan "$WebAppName-plan" --name $WebAppName --runtime "PYTHON:3.11"

# Python バージョンの設定
Write-Host "Python バージョンを設定中..." -ForegroundColor Yellow
az webapp config set --resource-group $ResourceGroupName --name $WebAppName --linux-fx-version "PYTHON:3.11"

# ZIPファイルを作成
Write-Host "デプロイ用ZIPファイルを作成中..." -ForegroundColor Yellow
$deployFiles = @(
    "app.py",
    "requirements.txt",
    "runtime.txt",
    "web.config"
)

# 既存のdeploy.zipを削除
if (Test-Path "deploy.zip") {
    Remove-Item "deploy.zip" -Force
}

# ZIPファイルを作成
Compress-Archive -Path $deployFiles -DestinationPath "deploy.zip" -Force

# デプロイ
Write-Host "アプリケーションをデプロイ中..." -ForegroundColor Yellow
az webapp deployment source config-zip --resource-group $ResourceGroupName --name $WebAppName --src .\deploy.zip

Write-Host "デプロイが完了しました！" -ForegroundColor Green
Write-Host "Web App URL: https://$WebAppName.azurewebsites.net" -ForegroundColor Cyan
Write-Host "Bot エンドポイント: https://$WebAppName.azurewebsites.net/api/messages" -ForegroundColor Cyan 