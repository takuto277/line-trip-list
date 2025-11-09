package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/line/line-bot-sdk-go/v8/linebot"
	"github.com/line/line-bot-sdk-go/v8/linebot/messaging_api"
	"github.com/line/line-bot-sdk-go/v8/linebot/webhook"
)

type Server struct {
	bot *messaging_api.MessagingApiAPI
	blob *messaging_api.MessagingApiBlobAPI
}

// iOSアプリに送信するメッセージ構造体
type AppMessage struct {
	GroupID   string `json:"group_id"`
	UserID    string `json:"user_id"`
	Message   string `json:"message"`
	Timestamp int64  `json:"timestamp"`
	UserName  string `json:"user_name"`
}

var server *Server

func init() {
	channelSecret := os.Getenv("LINE_CHANNEL_SECRET")
	channelToken := os.Getenv("LINE_CHANNEL_TOKEN")
	
	if channelSecret == "" || channelToken == "" {
		log.Printf("Warning: LINE API credentials not set")
		return
	}

	bot, err := messaging_api.NewMessagingApiAPI(channelToken)
	if err != nil {
		log.Printf("Error creating bot: %v", err)
		return
	}

	blob, err := messaging_api.NewMessagingApiBlobAPI(channelToken)
	if err != nil {
		log.Printf("Error creating blob: %v", err)
		return
	}

	server = &Server{
		bot: bot,
		blob: blob,
	}
}

func Handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	switch r.URL.Path {
	case "/health":
		healthCheck(w, r)
	case "/webhook":
		if server == nil {
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]string{"error": "Server not initialized"})
			return
		}
		server.handleWebhook(w, r)
	case "/send":
		if server == nil {
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]string{"error": "Server not initialized"})
			return
		}
		server.sendMessage(w, r)
	case "/":
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"status": "LINE Trip List Webhook Server",
			"version": "1.0.0",
			"endpoints": "/health, /webhook, /send",
		})
	default:
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{"error": "Not Found"})
	}
}

func (s *Server) handleWebhook(w http.ResponseWriter, r *http.Request) {
	cb, err := webhook.ParseRequest(os.Getenv("LINE_CHANNEL_SECRET"), r)
	if err != nil {
		log.Printf("Webhook parse error: %v", err)
		if err == linebot.ErrInvalidSignature {
			w.WriteHeader(400)
		} else {
			w.WriteHeader(500)
		}
		return
	}

	for _, event := range cb.Events {
		switch e := event.(type) {
		case webhook.MessageEvent:
			switch message := e.Message.(type) {
			case webhook.TextMessageContent:
				s.handleTextMessage(e, message)
			}
		}
	}

	w.WriteHeader(http.StatusOK)
}

func (s *Server) handleTextMessage(event webhook.MessageEvent, message webhook.TextMessageContent) {
	// グループソースを取得
	groupSource, ok := event.Source.(webhook.GroupSource)
	if !ok {
		// グループメッセージでない場合は処理しない
		return
	}

	// ユーザー情報を取得
	userName := "Unknown User"
	userID := ""
	
	// UserIdを安全に取得
	if groupSource.UserId != "" {
		userID = groupSource.UserId
		if len(userID) > 8 {
			userName = fmt.Sprintf("User-%s", userID[:8]) // 短縮表示
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

	// ここでiOSアプリに通知を送信
	s.notifyiOSApp(appMessage)

	log.Printf("📱 Group Message: %s from %s in group %s", 
		message.Text, userName, groupSource.GroupId)
}

func (s *Server) notifyiOSApp(message AppMessage) {
	// TODO: ここでiOSアプリに通知
	// 例: Firebase Cloud Messaging, WebSocket, HTTP POST等
	
	// とりあえずログ出力
	messageJSON, _ := json.MarshalIndent(message, "", "  ")
	fmt.Printf("📲 Notifying iOS App:\n%s\n", messageJSON)
}

func (s *Server) sendMessage(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		w.WriteHeader(405)
		return
	}

	var req struct {
		GroupID string `json:"group_id"`
		Message string `json:"message"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(400)
		return
	}

	if req.GroupID == "" || req.Message == "" {
		w.WriteHeader(400)
		return
	}

	_, err := s.bot.PushMessage(&messaging_api.PushMessageRequest{
		To: req.GroupID,
		Messages: []messaging_api.MessageInterface{
			&messaging_api.TextMessage{
				Text: req.Message,
			},
		},
	}, "")

	if err != nil {
		log.Printf("Send message error: %v", err)
		w.WriteHeader(500)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "success"})
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "ok",
		"service": "LINE Trip List Webhook",
		"timestamp": fmt.Sprintf("%d", 1699574400),
	})
}
