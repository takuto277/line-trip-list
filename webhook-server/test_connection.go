package main

import (
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	"github.com/line/line-bot-sdk-go/v8/linebot/messaging_api"
)

func main() {
	// 開発環境では.envファイルから読み込み
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found")
	}

	channelToken := os.Getenv("LINE_CHANNEL_TOKEN")
	if channelToken == "" {
		log.Fatal("LINE_CHANNEL_TOKEN が設定されていません")
	}

	bot, err := messaging_api.NewMessagingApiAPI(channelToken)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println("✅ LINE Bot API接続成功")
	fmt.Println("📝 ボットをLINEグループに追加して、グループでメッセージを送信してください")
	fmt.Println("🔍 サーバーログでGroup IDが確認できます")

	// ここで実際にはWebhookサーバーを起動
	fmt.Println("💡 サーバー起動コマンド: go run main.go")
}
