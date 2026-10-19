package main

import (
	"net/http"
	"strings"
	"testing"
	"time"
)

func TestCheck(t *testing.T) {
	secret := []byte("s3cret")
	now := time.Unix(1800000000, 0)
	valid := sign(secret, 1800003600, 37551)
	expired := sign(secret, 1799999999, 37551)
	other := sign([]byte("other"), 1800003600, 37551)
	t.Logf("valid: %s", valid)
	t.Logf("expired: %s", expired)
	t.Logf("other: %s", other)
	cases := []struct {
		label  string
		status int
	}{
		{valid, http.StatusOK},
		{strings.ToUpper(valid), http.StatusOK},
		{expired, http.StatusGone},
		{other, http.StatusForbidden},
		{strings.Replace(valid, "-p37551", "-p37553", 1), http.StatusForbidden},
		{strings.Replace(valid, "h6b49", "h6b4a", 1), http.StatusForbidden},
		{strings.Replace(valid, "-p37551", "-p037551", 1), http.StatusNotFound},
		{strings.Replace(valid, "-p37551", "-p99999", 1), http.StatusForbidden},
		{"p37551", http.StatusNotFound},
		{"", http.StatusNotFound},
	}
	for i, tc := range cases {
		if got := check(secret, tc.label, now); got != tc.status {
			t.Errorf("%d: check(%q): got %d, expected %d", i, tc.label, got, tc.status)
		}
	}
	if len(valid) > 63 {
		t.Errorf("label %q is too long", valid)
	}
}
