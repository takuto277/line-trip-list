package handler

import (
	"encoding/json"
	"net/http"
	"time"
)

// Message represents a stored LINE message
type Message struct {
	ID        int    `json:"id"`
	GroupID   string `json:"group_id"`
	UserID    string `json:"user_id"`
	Message   string `json:"message"`
	UserName  string `json:"user_name"`
	Timestamp int64  `json:"timestamp"`
	CreatedAt string `json:"created_at"`
}

// 一時的にメモリ内ストレージ（後でデータベースに置き換え）
var messages []Message
var messageID int = 1

func Handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	switch r.Method {
	case "GET":
		// メッセージ一覧を取得
		response := map[string]interface{}{
			"messages": messages,
			"count":    len(messages),
		}
		json.NewEncoder(w).Encode(response)

	case "POST":
		// 新しいメッセージを保存
		var msg Message
		if err := json.NewDecoder(r.Body).Decode(&msg); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{"error": "Invalid request body"})
			return
		}

		// IDと作成日時を設定
		msg.ID = messageID
		messageID++
		msg.CreatedAt = time.Now().Format(time.RFC3339)

		// メッセージを保存
		messages = append(messages, msg)

		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":  "success", 
			"message": "Message saved",
			"data":    msg,
		})

	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(map[string]string{"error": "Method not allowed"})
	}
}