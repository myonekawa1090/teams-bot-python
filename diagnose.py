#!/usr/bin/env python3
"""
Teams Bot 診断スクリプト
認証設定と環境変数の確認を行います
"""

import os
import sys
import asyncio
from dotenv import load_dotenv
from azure.identity.aio import ManagedIdentityCredential, DefaultAzureCredential

# .envファイルを読み込み
load_dotenv()

def check_environment():
    """環境変数の確認"""
    print("=== 環境変数の確認 ===")
    
    app_id = os.getenv("MicrosoftAppId", "")
    app_password = os.getenv("MicrosoftAppPassword", "")
    managed_id_client_id = os.getenv("ManagedIdentityClientId", "")
    
    print(f"MicrosoftAppId: {'✓' if app_id else '✗'} ({'設定済み' if app_id else '未設定'})")
    print(f"MicrosoftAppPassword: {'✓' if app_password else '✗'} ({'設定済み' if app_password else '未設定'})")
    print(f"ManagedIdentityClientId: {'✓' if managed_id_client_id else '✗'} ({'設定済み' if managed_id_client_id else '未設定'})")
    
    print(f"\n環境変数の値:")
    print(f"  MicrosoftAppId: {app_id[:8]}..." if app_id else "  MicrosoftAppId: (未設定)")
    print(f"  ManagedIdentityClientId: {managed_id_client_id[:8]}..." if managed_id_client_id else "  ManagedIdentityClientId: (未設定)")
    print(f"  MicrosoftAppPassword: {'*' * 8 if app_password else '(未設定)'}")
    
    return app_id, app_password, managed_id_client_id

def determine_auth_method(app_id, app_password, managed_id_client_id):
    """認証方式の決定"""
    print("\n=== 認証方式の決定 ===")
    
    if not app_id:
        print("⚠️  MicrosoftAppId が設定されていません")
        return None
    
    if managed_id_client_id:
        print("✓ User Assigned Managed Identity を使用")
        return "UAMI"
    elif not app_password:
        print("✓ DefaultAzureCredential (System Managed Identity) を使用")
        return "DefaultAzureCredential"
    else:
        print("✓ Client Secret authentication を使用")
        return "ClientSecret"

async def test_credentials(auth_method, app_id, app_password, managed_id_client_id):
    """認証情報のテスト"""
    print("\n=== 認証情報のテスト ===")
    
    try:
        if auth_method == "UAMI":
            credential = ManagedIdentityCredential(client_id=managed_id_client_id)
            print("User Assigned Managed Identity の初期化: ✓")
        elif auth_method == "DefaultAzureCredential":
            credential = DefaultAzureCredential()
            print("DefaultAzureCredential の初期化: ✓")
        else:
            print("Client Secret 認証: ✓")
            return True
            
        # 実際にトークンを取得してみる（Bot Framework用）
        if auth_method in ["UAMI", "DefaultAzureCredential"]:
            print("トークン取得のテスト中...")
            try:
                # Bot Framework のスコープでトークンを取得
                token = await credential.get_token("https://api.botframework.com/.default")
                print("✓ トークンの取得に成功")
                print(f"  トークンタイプ: {type(token.token)}")
                print(f"  有効期限: {token.expires_on}")
                return True
            except Exception as e:
                print(f"✗ トークンの取得に失敗: {e}")
                return False
        
    except Exception as e:
        print(f"✗ 認証設定エラー: {e}")
        return False

def print_recommendations():
    """推奨設定の表示"""
    print("\n=== 推奨設定 ===")
    print("1. Azure Web App にデプロイする場合:")
    print("   - System Assigned Managed Identity を有効にする")
    print("   - MicrosoftAppId のみ設定し、MicrosoftAppPassword は設定しない")
    print("   - Bot Framework Registration の認証設定を確認")
    
    print("\n2. User Assigned Managed Identity を使用する場合:")
    print("   - MicrosoftAppId と ManagedIdentityClientId を設定")
    print("   - MicrosoftAppPassword は設定しない")
    print("   - Azure リソースに適切な Role Assignment を設定")
    
    print("\n3. 開発環境またはオンプレミス:")
    print("   - MicrosoftAppId と MicrosoftAppPassword を設定")
    print("   - Bot Framework Registration でクライアントシークレットを生成")

async def main():
    """メイン診断関数"""
    print("Teams Bot 診断スクリプトを開始します...\n")
    
    # 環境変数の確認
    app_id, app_password, managed_id_client_id = check_environment()
    
    # 認証方式の決定
    auth_method = determine_auth_method(app_id, app_password, managed_id_client_id)
    
    if auth_method:
        # 認証情報のテスト
        success = await test_credentials(auth_method, app_id, app_password, managed_id_client_id)
        
        if success:
            print("\n✅ 診断結果: 認証設定は正常です")
        else:
            print("\n❌ 診断結果: 認証設定に問題があります")
            print_recommendations()
    else:
        print("\n❌ 診断結果: 必要な環境変数が設定されていません")
        print_recommendations()

if __name__ == "__main__":
    asyncio.run(main())
