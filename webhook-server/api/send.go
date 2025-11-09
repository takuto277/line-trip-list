package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/line/line-bot-sdk-go/v8/linebot/messaging_api"
)

type SendMessageRequest struct {
	GroupID string `json:"group_id"`
	Message string `json:"message"`
}

func Handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	if r.Method != "POST" {
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(map[string]string{"error": "Method not allowed"})
		return
	}

	channelToken := os.Getenv("LINE_CHANNEL_TOKEN")
	if channelToken == "" {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "LINE_CHANNEL_TOKEN not configured"})
		return
	}

	var req SendMessageRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Invalid request body"})
		return
	}

	if req.GroupID == "" || req.Message == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "group_id and message are required"})
		return
	}

	bot, err := messaging_api.NewMessagingApiAPI(channelToken)
	if err != nil {
		log.Printf("Error creating bot: %v", err)
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to initialize LINE bot"})
		return
	}

	_, err = bot.PushMessage(&messaging_api.PushMessageRequest{
		To: req.GroupID,
		Messages: []messaging_api.MessageInterface{
			&messaging_api.TextMessage{
				Text: req.Message,
			},
		},
	}, "")

	if err != nil {
		log.Printf("Send message error: %v", err)
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to send message"})
		return
	}

	json.NewEncoder(w).Encode(map[string]string{"status": "success"})
}