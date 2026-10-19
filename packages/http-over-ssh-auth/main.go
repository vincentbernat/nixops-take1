// Sign and check hostnames for http-over-ssh. The first label of a hostname is
// h<expires><mac>-p<port>. expires is a 32-bit Unix time and mac is the
// HMAC-SHA256 of expires and port, cut to 64 bits. Both are in hex as hostnames
// are not case-sensitive.
package main

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

const macSize = 8

var labelRegexp = regexp.MustCompile(`^h([0-9a-f]{8})([0-9a-f]{16})-p([1-9][0-9]{0,4})$`)

// mac returns the HMAC-SHA256 value for secret, expiration date, and port.
func mac(secret []byte, expires uint32, port uint16) []byte {
	h := hmac.New(sha256.New, secret)
	h.Write(binary.BigEndian.AppendUint32(nil, expires))
	h.Write(binary.BigEndian.AppendUint16(nil, port))
	return h.Sum(nil)[:macSize]
}

// sign returns the hex-encoded label.
func sign(secret []byte, expires uint32, port uint16) string {
	return fmt.Sprintf("h%08x%x-p%d", expires, mac(secret, expires, port), port)
}

// check returns the HTTP status for the first label of a hostname.
func check(secret []byte, label string, now time.Time) int {
	match := labelRegexp.FindStringSubmatch(strings.ToLower(label))
	if match == nil {
		return http.StatusNotFound
	}
	expires, _ := strconv.ParseUint(match[1], 16, 32)
	got, _ := hex.DecodeString(match[2])
	port, _ := strconv.ParseUint(match[3], 10, 16)
	if !hmac.Equal(got, mac(secret, uint32(expires), uint16(port))) {
		return http.StatusForbidden
	}
	if int64(expires) <= now.Unix() {
		return http.StatusGone
	}
	return http.StatusOK
}

// serve answers Caddy forward_auth requests. The path is the label to check.
// It stops after some time without requests. systemd keeps the socket and
// starts it again on the next connection.
func serve(secret []byte, idle time.Duration) {
	if os.Getenv("LISTEN_FDS") != "1" {
		log.Fatal("expected one socket from systemd")
	}
	listener, err := net.FileListener(os.NewFile(3, "socket"))
	if err != nil {
		log.Fatalf("cannot listen to socket: %v", err)
	}

	activity := make(chan struct{}, 1)
	server := &http.Server{
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			select {
			case activity <- struct{}{}:
			default:
			}
			w.WriteHeader(check(secret, strings.TrimPrefix(r.URL.Path, "/"), time.Now()))
		}),
	}
	stopped := make(chan struct{})
	go func() {
		defer close(stopped)
		timer := time.NewTimer(idle)
		for {
			select {
			case <-activity:
				timer.Reset(idle)
			case <-timer.C:
				if err := server.Shutdown(context.Background()); err != nil {
					log.Printf("cannot shuwtdown server: %v", err)
				}
				return
			}
		}
	}()
	if err := server.Serve(listener); err != http.ErrServerClosed {
		log.Fatalf("cannot serve HTTP requests: %v", err)
	}
	<-stopped
}

func main() {
	secretFile := flag.String("secret",
		filepath.Join(os.Getenv("CREDENTIALS_DIRECTORY"), "secret"),
		"file with the secret")
	idle := flag.Duration("idle", time.Minute, "time without requests before serve stops")
	flag.Usage = func() {
		fmt.Fprintf(flag.CommandLine.Output(),
			"Usage: %s [-secret FILE] [-idle DURATION] serve|sign PORT SECONDS\n",
			os.Args[0])
		flag.PrintDefaults()
	}
	flag.Parse()

	secret, err := os.ReadFile(*secretFile)
	if err != nil {
		log.Fatalf("cannot read secret: %v", err)
	}
	secret = bytes.TrimSpace(secret)

	switch {
	case flag.NArg() == 1 && flag.Arg(0) == "serve":
		serve(secret, *idle)
	case flag.NArg() == 3 && flag.Arg(0) == "sign":
		port, err := strconv.ParseUint(flag.Arg(1), 10, 16)
		if err != nil || port == 0 {
			log.Fatalf("invalid port %q", flag.Arg(1))
		}
		lifetime, err := strconv.ParseInt(flag.Arg(2), 10, 32)
		if err != nil {
			log.Fatalf("invalid lifetime %q", flag.Arg(2))
		}
		fmt.Println(sign(secret, uint32(time.Now().Unix()+lifetime), uint16(port)))
	default:
		flag.Usage()
		os.Exit(2)
	}
}
