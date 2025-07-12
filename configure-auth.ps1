# Teams Bot 認証設定スクリプト
# Azure Web App での認証設定を支援します

param(
    [Parameter(Mandatory=$true)]
    [string]$WebAppName,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$MicrosoftAppId,
    
    [Parameter(Mandatory=$false)]
    [string]$MicrosoftAppPassword = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ManagedIdentityClientId = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableSystemManagedIdentity,
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowCurrentConfig
)

Write-Host "Teams Bot 認証設定スクリプト" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

# 現在の設定表示
if ($ShowCurrentConfig) {
    Write-Host "現在の設定を取得中..." -ForegroundColor Yellow
    
    $currentSettings = az webapp config appsettings list --name $WebAppName --resource-group $ResourceGroupName --query "[?name=='MicrosoftAppId' || name=='MicrosoftAppPassword' || name=='ManagedIdentityClientId']" -o json | ConvertFrom-Json
    
    Write-Host "現在の環境変数:" -ForegroundColor Cyan
    foreach ($setting in $currentSettings) {
        if ($setting.name -eq "MicrosoftAppPassword") {
            Write-Host "  $($setting.name): $('*' * $setting.value.Length)" -ForegroundColor White
        } else {
            Write-Host "  $($setting.name): $($setting.value)" -ForegroundColor White
        }
    }
    
    # Managed Identity の状態確認
    $identity = az webapp identity show --name $WebAppName --resource-group $ResourceGroupName -o json | ConvertFrom-Json
    Write-Host "Managed Identity 設定:" -ForegroundColor Cyan
    Write-Host "  System Assigned: $($identity.type -eq 'SystemAssigned' -or $identity.type -eq 'SystemAssigned,UserAssigned')" -ForegroundColor White
    Write-Host "  User Assigned: $($identity.type -eq 'UserAssigned' -or $identity.type -eq 'SystemAssigned,UserAssigned')" -ForegroundColor White
}

# System Managed Identity の有効化
if ($EnableSystemManagedIdentity) {
    Write-Host "System Managed Identity を有効化中..." -ForegroundColor Yellow
    
    az webapp identity assign --name $WebAppName --resource-group $ResourceGroupName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ System Managed Identity が有効化されました" -ForegroundColor Green
    } else {
        Write-Host "✗ System Managed Identity の有効化に失敗しました" -ForegroundColor Red
        exit 1
    }
}

# 環境変数の設定
Write-Host "環境変数を設定中..." -ForegroundColor Yellow

# 必須: MicrosoftAppId
az webapp config appsettings set --name $WebAppName --resource-group $ResourceGroupName --settings "MicrosoftAppId=$MicrosoftAppId"

# 認証方式に応じた設定
if ($ManagedIdentityClientId) {
    Write-Host "User Assigned Managed Identity を設定中..." -ForegroundColor Yellow
    az webapp config appsettings set --name $WebAppName --resource-group $ResourceGroupName --settings "ManagedIdentityClientId=$ManagedIdentityClientId"
    
    # MicrosoftAppPassword は削除
    az webapp config appsettings delete --name $WebAppName --resource-group $ResourceGroupName --setting-names "MicrosoftAppPassword"
    
    Write-Host "✓ User Assigned Managed Identity が設定されました" -ForegroundColor Green
    
} elseif ($MicrosoftAppPassword) {
    Write-Host "Client Secret 認証を設定中..." -ForegroundColor Yellow
    az webapp config appsettings set --name $WebAppName --resource-group $ResourceGroupName --settings "MicrosoftAppPassword=$MicrosoftAppPassword"
    
    # ManagedIdentityClientId は削除
    az webapp config appsettings delete --name $WebAppName --resource-group $ResourceGroupName --setting-names "ManagedIdentityClientId"
    
    Write-Host "✓ Client Secret 認証が設定されました" -ForegroundColor Green
    
} else {
    Write-Host "DefaultAzureCredential (System Managed Identity) を設定中..." -ForegroundColor Yellow
    
    # 不要な環境変数を削除
    az webapp config appsettings delete --name $WebAppName --resource-group $ResourceGroupName --setting-names "MicrosoftAppPassword"
    az webapp config appsettings delete --name $WebAppName --resource-group $ResourceGroupName --setting-names "ManagedIdentityClientId"
    
    Write-Host "✓ DefaultAzureCredential が設定されました" -ForegroundColor Green
}

# 設定完了
Write-Host "設定が完了しました！" -ForegroundColor Green
Write-Host "Web App を再起動して設定を反映してください:" -ForegroundColor Yellow
Write-Host "  az webapp restart --name $WebAppName --resource-group $ResourceGroupName" -ForegroundColor Cyan

# 確認用コマンド
Write-Host "`n設定確認用コマンド:" -ForegroundColor Yellow
Write-Host "  PowerShell: .\configure-auth.ps1 -WebAppName $WebAppName -ResourceGroupName $ResourceGroupName -MicrosoftAppId $MicrosoftAppId -ShowCurrentConfig" -ForegroundColor Cyan
Write-Host "  Health Check: curl https://$WebAppName.azurewebsites.net/health" -ForegroundColor Cyan
