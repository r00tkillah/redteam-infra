package main

import (
	"bytes"
	"encoding/base64"
	"io"
	"os"
	"strconv"
	"strings"
	"testing"

	"github.com/kdomanski/iso9660"
)

func TestCreateHTMLIncludesPayloadAndFilename(t *testing.T) {
	payload := []byte{0x00, 0x01, 0xfe, 0xff, 'A'}
	output, err := os.CreateTemp(t.TempDir(), "output-*.html")
	if err != nil {
		t.Fatal(err)
	}

	if err := createHTML(payload, "payload.bin", output); err != nil {
		t.Fatal(err)
	}
	if err := output.Close(); err != nil {
		t.Fatal(err)
	}

	got, err := os.ReadFile(output.Name())
	if err != nil {
		t.Fatal(err)
	}
	prefix := `var dataurl = "`
	_, dataURL, found := strings.Cut(string(got), prefix)
	if !found {
		t.Fatal("generated HTML does not define dataurl")
	}
	dataURL, _, found = strings.Cut(dataURL, `";`)
	if !found {
		t.Fatal("generated HTML has an unterminated dataurl")
	}
	dataURL, err = strconv.Unquote(`"` + strings.ReplaceAll(dataURL, `\/`, `/`) + `"`)
	if err != nil {
		t.Fatalf("decode generated JavaScript string: %v", err)
	}
	wantDataURL := "data:application/octet-stream;base64," + base64.StdEncoding.EncodeToString(payload)
	if dataURL != wantDataURL {
		t.Errorf("generated data URL = %q, want %q", dataURL, wantDataURL)
	}
	if !bytes.Contains(got, []byte(`downloadURI(dataurl, "payload.bin")`)) {
		t.Errorf("generated HTML does not use the requested filename")
	}
}

func TestGenerateISO9660(t *testing.T) {
	wantPayload := []byte("payload contents")
	data, err := generateISO9660([]FSItem{{Pathname: "payload.bin", Content: wantPayload}}, "SMUGGLEBUS")
	if err != nil {
		t.Fatal(err)
	}

	image, err := iso9660.OpenImage(bytes.NewReader(data))
	if err != nil {
		t.Fatal(err)
	}
	label, err := image.Label()
	if err != nil {
		t.Fatal(err)
	}
	if got := strings.TrimSpace(label); got != "SMUGGLEBUS" {
		t.Errorf("volume label = %q, want %q", got, "SMUGGLEBUS")
	}

	root, err := image.RootDir()
	if err != nil {
		t.Fatal(err)
	}
	files, err := root.GetChildren()
	if err != nil {
		t.Fatal(err)
	}
	if len(files) != 1 {
		t.Fatalf("root contains %d files, want 1", len(files))
	}
	if got := files[0].Name(); got != "payload.bin" {
		t.Fatalf("filename = %q, want %q", got, "payload.bin")
	}
	gotPayload, err := io.ReadAll(files[0].Reader())
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(gotPayload, wantPayload) {
		t.Errorf("payload = %q, want %q", gotPayload, wantPayload)
	}
}
