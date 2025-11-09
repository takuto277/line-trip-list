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

1. Vercelプロジェクト作成
2. 環境変数設定（LINE_CHANNEL_SECRET, LINE_CHANNEL_TOKEN）
3. LINE Developer Consoleでwebhook URL設定

## 取得が必要な情報

### LINE Developer Console
1. **Channel Secret** - Basic settings
2. **Channel Access Token** - Messaging API settings（Issue buttonで発行）
3. **Group ID** - ボットをグループに追加後、メッセージから取得

### Group ID取得方法
1. ボットをLINEグループに追加
2. グループでメッセージ送信
3. サーバーログでGroup IDを確認
