package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
)

var version = "dev"

func newMux() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok", "version": version})
	})
	return mux
}

func main() {
	// Parse PORT as a number so a malformed value fails fast and never reaches the log verbatim.
	port := 8000
	if v := os.Getenv("PORT"); v != "" {
		p, err := strconv.Atoi(v)
		if err != nil || p < 1 || p > 65535 {
			log.Fatal("PORT must be a number between 1 and 65535")
		}
		port = p
	}
	srv := &http.Server{
		Addr:              ":" + strconv.Itoa(port),
		Handler:           newMux(),
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Printf("listening on :%d (version %s)", port, version)
	log.Fatal(srv.ListenAndServe())
}
