package main

import (
	"os"
	"time"
)

var initialized = []byte("initialized Go data")

func main() {
	if len(os.Args) == 0 || len(initialized) != 19 {
		os.Exit(31)
	}
	result := make(chan byte)
	go func() {
		allocation := make([]byte, 4096)
		allocation[3072] = initialized[0]
		result <- allocation[3072]
	}()
	if <-result != 'i' || time.Now().Unix() <= 0 {
		os.Exit(32)
	}
	os.Stdout.WriteString("embedded static Go ready\n")
	if len(os.Args) > 1 {
		os.Stdout.WriteString(os.Args[1] + "\n")
	}
	if marker := os.Getenv("FORTH_MARKER"); marker != "" {
		os.Stdout.WriteString(marker + "\n")
	}
}
