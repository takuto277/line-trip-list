# LINE Webhook Server

LINE Messaging APIのWebhookを受信し、iOSアプリとの中継を行うGoサーバーです。

## セットアップ

### 1. 環境変数設定
```bash
cp .env.example .env
# .envファイルを編集して実際の値を設定
```

### 2. 依存関係インストール
```bash
go mod tidy
```

### 3. ローカル実行
```bash
go run main.go
```

### 4. ngrokでトンネル作成（開発用）
```bash
# 別ターミナルで
ngrok http 8080
```

## API エンドポイント

### Webhook受信
- `POST /webhook` - LINE Messaging APIからのWebhook

### メッセージ送信
- `POST /send` - iOSアプリからのメッセージ送信
```json
{
  "group_id": "GROUP_ID",
  "message": "メッセージ内容"
}
```

### ヘルスチェック
- `GET /health` - サーバー生存確認

## Vercelデプロイ

### 重要な設定

1. **Root Directoryの設定**
   - Vercelのダッシュボードで、プロジェクト設定を開く
   - 「Root Directory」を`webhook-server`に設定する
   - これが設定されていないと、404エラーが発生します

2. **環境変数の設定**
   - Vercelのダッシュボードで、環境変数を設定
   - `LINE_CHANNEL_SECRET`: LINE Developer ConsoleのBasic settingsから取得
   - `LINE_CHANNEL_TOKEN`: LINE Developer ConsoleのMessaging API settingsから発行

3. **デプロイ**
   - GitHubにプッシュすると自動デプロイされます
   - または、Vercel CLIで`vercel`コマンドを実行

4. **Webhook URLの設定**
   - LINE Developer Consoleで、Webhook URLを設定
   - URL: `https://your-project.vercel.app/webhook`

### トラブルシューティング

- 404エラーが発生する場合：
  1. Root Directoryが`webhook-server`に設定されているか確認
  2. `vercel.json`が`webhook-server`ディレクトリに存在するか確認
  3. デプロイログでエラーがないか確認

## 取得が必要な情報

### LINE Developer Console
1. **Channel Secret** - Basic settings
2. **Channel Access Token** - Messaging API settings（Issue buttonで発行）
3. **Group ID** - ボットをグループに追加後、メッセージから取得

### Group ID取得方法
1. ボットをLINEグループに追加
2. グループでメッセージ送信
3. サーバーログでGroup IDを確認
