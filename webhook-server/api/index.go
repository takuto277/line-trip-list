package handler

import (
	"encoding/json"
	"net/http"
)

func Handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	
	response := map[string]interface{}{
		"status": "ok",
		"service": "LINE Trip List Webhook Server",
		"endpoints": []string{"/api/health", "/api/webhook", "/api/send", "/api/messages"},
		"version": "1.0.0",
	}
	
	json.NewEncoder(w).Encode(response)
}