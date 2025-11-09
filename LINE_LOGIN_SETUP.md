# LINE Login設定ガイド

## 1. LINE Login Channelの作成

1. [LINE Developers Console](https://developers.line.biz/console/)にアクセス
2. 既存のProviderを選択
3. **「Create a LINE Login channel」**をクリック
4. 以下の情報を入力：
   - **Channel name**: `line-trip-list`
   - **Channel description**: `LINE Trip List App`
   - **App types**: iOS

## 2. iOS設定

### アプリ設定タブで：
- **iOS bundle ID**: Xcodeで確認した Bundle Identifier を入力
  - 例: `com.yourname.line-trip-list`
- **iOS scheme**: `line-trip-list`

## 3. Channel情報を取得

**Basic settings**タブで以下をコピー：
- **Channel ID**: 数字（例: 2012345678）

## 4. Xcodeでの設定

### Info.plistに追加：

1. Xcodeでプロジェクトを開く
2. `Info.plist`を右クリック → **Open As** → **Source Code**
3. 以下を`<dict>`内に追加：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>line-trip-list</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>line-trip-list</string>
        </array>
    </dict>
</array>
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>lineauth2</string>
</array>
```

### line_api_env.shに追加：

```bash
# LINE Login Channel ID（番号のみ）
export LINE_CHANNEL_ID="2012345678"  # 実際のChannel IDに置き換え
```

## 5. 動作確認

1. Xcodeでアプリをビルド・実行
2. ログイン画面で「LINEでログイン」をタップ
3. Safariでログイン画面が開く
4. ログイン後、アプリに戻る
5. メイン画面が表示される

## トラブルシューティング

### ログインできない場合：
- Channel IDが正しいか確認
- iOS Bundle IDが正しいか確認
- URL Schemeが設定されているか確認
- `line_api_env.sh`が読み込まれているか確認

### アプリに戻らない場合：
- URL Scheme `line-trip-list` が正しく設定されているか確認
- Xcodeスキームの設定で環境変数が読み込まれているか確認