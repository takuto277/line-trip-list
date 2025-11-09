package handler

import (
	"encoding/json"
	"net/http"
	"time"
)

func Handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	
	response := map[string]interface{}{
		"status":    "ok",
		"timestamp": time.Now().Unix(),
		"service":   "LINE Trip List Webhook",
	}
	
	json.NewEncoder(w).Encode(response)
}