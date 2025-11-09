# LINE Trip List Webhook Server

Vercelデプロイ済み: https://line-trip-list.vercel.app

## 重要な設定

### Vercelプロジェクト設定
1. **Root Directory**: `webhook-server` に設定
2. **Environment Variables**:
   - `LINE_CHANNEL_SECRET`
   - `LINE_CHANNEL_TOKEN`

### LINE Developer Console設定
- **Webhook URL**: `https://line-trip-list.vercel.app/api/webhook`
- **Use webhook**: ON
- **Auto-reply messages**: OFF（自動返信を無効化）
- **Greeting messages**: OFF（あいさつメッセージを無効化）

## エンドポイント

- `GET /api/health` - ヘルスチェック
- `POST /api/webhook` - LINE Webhook受信
- `POST /api/send` - メッセージ送信
- `GET /api/messages` - メッセージ取得
- `POST /api/messages` - メッセージ保存
- `GET /` または `GET /api` - サービス情報

## ローカル開発

```bash
# 環境変数設定
cp .env.example .env
# .env ファイルを編集

# 依存関係インストール
go mod tidy

# サーバー起動
go run main.go
```