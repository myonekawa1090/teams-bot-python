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
az webapp create --resource-group $ResourceGroupName --plan "$WebAppName-plan" --name $WebAppName --runtime "PYTHON|3.11"

# Python バージョンの明示的な設定
Write-Host "Python バージョンを明示的に設定中..." -ForegroundColor Yellow
az webapp config set --resource-group $ResourceGroupName --name $WebAppName --linux-fx-version "PYTHON|3.11"

# アプリケーション設定の追加
Write-Host "アプリケーション設定を追加中..." -ForegroundColor Yellow
az webapp config appsettings set --resource-group $ResourceGroupName --name $WebAppName --settings `
    SCM_DO_BUILD_DURING_DEPLOYMENT=true `
    ENABLE_ORYX_BUILD=false `
    PYTHON_VERSION=3.11 `
    STARTUP_COMMAND="python3 -m pip install -r requirements.txt && python3 app.py"

# ZIPファイルを作成
Write-Host "デプロイ用ZIPファイルを作成中..." -ForegroundColor Yellow
$deployFiles = @(
    "app.py",
    "requirements.txt",
    "runtime.txt"
)

# 既存のdeploy.zipを削除
if (Test-Path "deploy.zip") {
    Remove-Item "deploy.zip" -Force
}

# ZIPファイルを作成
Compress-Archive -Path $deployFiles -DestinationPath "deploy.zip" -Force

# デプロイ
Write-Host "アプリケーションをデプロイ中..." -ForegroundColor Yellow
az webapp deploy --resource-group $ResourceGroupName --name $WebAppName --src-path .\deploy.zip --type zip

Write-Host "デプロイが完了しました！" -ForegroundColor Green
Write-Host "Web App URL: https://$WebAppName.azurewebsites.net" -ForegroundColor Cyan
Write-Host "Bot エンドポイント: https://$WebAppName.azurewebsites.net/api/messages" -ForegroundColor Cyan

# デプロイ後の確認
Write-Host ""
Write-Host "デプロイ後の確認を開始します..." -ForegroundColor Yellow

# アプリケーションの起動を待機
Write-Host "アプリケーションの起動を待機中..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# ヘルスチェック
Write-Host "ヘルスチェックを実行中..." -ForegroundColor Yellow
try {
    $healthResponse = Invoke-WebRequest -Uri "https://$WebAppName.azurewebsites.net/health" -Method GET -TimeoutSec 30
    Write-Host "ヘルスチェック成功: $($healthResponse.StatusCode)" -ForegroundColor Green
    Write-Host "レスポンス: $($healthResponse.Content)" -ForegroundColor Cyan
} catch {
    Write-Host "ヘルスチェック失敗: $($_.Exception.Message)" -ForegroundColor Red
}

# ログの確認
Write-Host ""
Write-Host "最新のログを確認中..." -ForegroundColor Yellow
az webapp log show --name $WebAppName --resource-group $ResourceGroupName --query "[?timestamp>='$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')']" --output table

# Bot Service 作成
Write-Host ""
Write-Host "Bot Service 作成を開始します..." -ForegroundColor Green

# Bot名を設定
$botName = "$WebAppName-bot"

# User Assigned Managed Identity を作成
Write-Host "User Assigned Managed Identity を作成中..." -ForegroundColor Yellow
$identityName = "$botName-identity"
az identity create --resource-group $ResourceGroupName --name $identityName --location $Location

# 作成されたIdentityの情報を取得
$identityInfo = az identity show --resource-group $ResourceGroupName --name $identityName | ConvertFrom-Json
$identityId = $identityInfo.id
$identityClientId = $identityInfo.clientId
$identityTenantId = $identityInfo.tenantId
$identityPrincipalId = $identityInfo.principalId

Write-Host "Managed Identity 作成完了: $identityName" -ForegroundColor Green
Write-Host "Identity ID: $identityId" -ForegroundColor Cyan
# Bot Service を作成 (User Assigned Managed Identity使用)
Write-Host "Bot Service を作成中..." -ForegroundColor Yellow
az bot create --resource-group $ResourceGroupName --name $botName --app-type UserAssignedMSI  --msi-resource-id $identityId --name $botName --appid $identityClientId --tenant-id $identityTenantId

# Bot エンドポイント設定
Write-Host "Bot エンドポイントを設定中..." -ForegroundColor Yellow
az bot webchat create --name $botName --resource-group $ResourceGroupName

# Messaging エンドポイント設定
Write-Host "Messaging エンドポイントを設定中..." -ForegroundColor Yellow
az bot update --name $botName --resource-group $ResourceGroupName --endpoint "https://$WebAppName.azurewebsites.net/api/messages"

Write-Host "Bot Service 作成が完了しました！" -ForegroundColor Green
Write-Host "Bot 管理ページ: https://portal.azure.com/#@/resource/subscriptions/dfcbc91f-8897-4cf8-b403-e0745528c563/resourceGroups/$ResourceGroupName/providers/Microsoft.BotService/botServices/$botName" -ForegroundColor Cyan
Write-Host "Teams で使用するには、Bot 管理ページからTeamsチャンネルを手動で追加してください。" -ForegroundColor Cyan
Write-Host ""
Write-Host "Managed Identity 情報:" -ForegroundColor Yellow
Write-Host "名前: $identityName" -ForegroundColor White
Write-Host "ID: $identityId" -ForegroundColor White