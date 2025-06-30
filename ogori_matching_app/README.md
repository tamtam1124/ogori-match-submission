# おごりマッチングアプリ

## チーム開発セットアップ

### 1. リポジトリをclone
```bash
git clone <repository-url>
cd ogori_matching_app
```

### 2. Firebase設定ファイルを作成
```bash
# 環境変数ファイルを作成
cp .env.example .env

# .env を編集して実際のFirebase設定値を入力
# (チームメンバーから設定値を取得してください)
```

### 3. 依存関係のインストール & 実行
```bash
flutter pub get
flutter run --dart-define-from-file=.env
```

## Firebase設定

チームメンバーは以下の設定値を `.env` ファイルに設定してください：

- **FIREBASE_WEB_API_KEY**: Firebase Console > プロジェクト設定 > 全般 > ウェブAPIキー
- **FIREBASE_WEB_APP_ID**: Firebase Console > プロジェクト設定 > 全般 > アプリID (Web)
- **FIREBASE_ANDROID_API_KEY**: Firebase Console > プロジェクト設定 > 全般 > AndroidAPIキー
- **FIREBASE_ANDROID_APP_ID**: Firebase Console > プロジェクト設定 > 全般 > アプリID (Android)
- **FIREBASE_IOS_API_KEY**: Firebase Console > プロジェクト設定 > 全般 > iOSAPIキー
- **FIREBASE_IOS_APP_ID**: Firebase Console > プロジェクト設定 > 全般 > アプリID (iOS)
- **FIREBASE_PROJECT_ID**: `ogori-match`
- **FIREBASE_MESSAGING_SENDER_ID**: Firebase Console > プロジェクト設定 > 全般 > 送信者ID

## 機能

- 🤝 リアルタイムマッチング
- 🎯 二段階マッチングアルゴリズム
- 🔥 Firebase認証・Firestore
- 📱 レスポンシブUI

## 技術スタック

- **Frontend**: Flutter 3.x
- **Backend**: Firebase (Firestore, Authentication)
- **言語**: Dart 3.x

## 注意事項

- `.env` ファイルは個人で管理してください（Git管理外）
- 実行時は `flutter run --dart-define-from-file=.env` を使用してください
- Firebase設定値はチームメンバーから取得してください
- Firebase設定値はチーム内で共有してください
- 新しいチームメンバーには設定値を直接伝えてください
