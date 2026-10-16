package main

import (
	"context"
	"encoding/json"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

// Set at build time via -ldflags (see Dockerfile / Makefile)
var (
	version = "dev"
	commit  = "none"
)

type response struct {
	Message string `json:"message"`
	Status  string `json:"status"`
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response{
		Message: "Hello from DevOps Intern Task!",
		Status:  "running",
	})
}

// healthcheck lets the distroless/scratch image check itself (no curl/shell inside).
func healthcheck(addr string) {
	client := http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get("http://" + addr + "/")
	if err != nil || resp.StatusCode != http.StatusOK {
		os.Exit(1)
	}
	os.Exit(0)
}

func main() {
	hc := flag.Bool("healthcheck", false, "run health check and exit")
	flag.Parse()
	if *hc {
		healthcheck("127.0.0.1:8080")
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", indexHandler)

	srv := &http.Server{
		Addr:              ":8080",
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		log.Printf("Server listening on :8080 (version=%s commit=%s)", version, commit)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server error: %v", err)
		}
	}()

	// Graceful shutdown on SIGTERM/SIGINT (docker stop)
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	srv.Shutdown(ctx)
	log.Println("Server stopped")
}
