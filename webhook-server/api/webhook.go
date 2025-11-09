package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/line/line-bot-sdk-go/v8/linebot"
	"github.com/line/line-bot-sdk-go/v8/linebot/messaging_api"
	"github.com/line/line-bot-sdk-go/v8/linebot/webhook"
)

// AppMessage represents a LINE message for the iOS app
type AppMessage struct {
	GroupID   string `json:"group_id"`
	UserID    string `json:"user_id"`
	Message   string `json:"message"`
	Timestamp int64  `json:"timestamp"`
	UserName  string `json:"user_name"`
}

func Handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, X-Line-Signature")

	if r.Method != "POST" {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	channelSecret := os.Getenv("LINE_CHANNEL_SECRET")
	if channelSecret == "" {
		log.Printf("LINE_CHANNEL_SECRET not set")
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	cb, err := webhook.ParseRequest(channelSecret, r)
	if err != nil {
		log.Printf("Webhook parse error: %v", err)
		if err == linebot.ErrInvalidSignature {
			w.WriteHeader(http.StatusBadRequest)
		} else {
			w.WriteHeader(http.StatusInternalServerError)
		}
		return
	}

	for _, event := range cb.Events {
		switch e := event.(type) {
		case webhook.MessageEvent:
			switch message := e.Message.(type) {
			case webhook.TextMessageContent:
				handleTextMessage(e, message)
			}
		}
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "success"})
}

func handleTextMessage(event webhook.MessageEvent, message webhook.TextMessageContent) {
	// グループソースを取得
	groupSource, ok := event.Source.(webhook.GroupSource)
	if !ok {
		log.Printf("Not a group message, skipping")
		return
	}

	// ユーザー情報を取得
	userName := "Unknown User"
	userID := ""
	
	if groupSource.UserId != "" {
		userID = groupSource.UserId
		if len(userID) > 8 {
			userName = fmt.Sprintf("User-%s", userID[:8])
		} else {
			userName = fmt.Sprintf("User-%s", userID)
		}
	}

	appMessage := AppMessage{
		GroupID:   groupSource.GroupId,
		UserID:    userID,
		Message:   message.Text,
		Timestamp: event.Timestamp,
		UserName:  userName,
	}

	// TODO: ここでデータベースに保存
	notifyiOSApp(appMessage)

	log.Printf("📱 Group Message: %s from %s in group %s", 
		message.Text, userName, groupSource.GroupId)
}

func notifyiOSApp(message AppMessage) {
	// メッセージログ出力
	messageJSON, _ := json.MarshalIndent(message, "", "  ")
	log.Printf("📲 Received LINE Message:\n%s", messageJSON)
	
	// メッセージをAPIに保存
	saveMessage(message)
}

func saveMessage(message AppMessage) {
	// 同じサーバーの /api/messages エンドポイントにPOST
	messageJSON, err := json.Marshal(message)
	if err != nil {
		log.Printf("Error marshaling message: %v", err)
		return
	}

	// 環境によってベースURLを変更
	baseURL := os.Getenv("VERCEL_URL")
	if baseURL == "" {
		baseURL = "https://line-trip-list.vercel.app"
	}
	
	resp, err := http.Post(baseURL+"/api/messages", "application/json", bytes.NewBuffer(messageJSON))
	if err != nil {
		log.Printf("Error saving message: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusCreated {
		log.Printf("✅ Message saved successfully")
	} else {
		log.Printf("❌ Failed to save message, status: %d", resp.StatusCode)
	}
}