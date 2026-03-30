package message

import (
	"archive/zip"
	"bytes"
	"encoding/xml"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// documentMimeTypes are MIME types that should be converted to text rather than sent as binary.
var documentMimeTypes = map[string]bool{
	"application/vnd.openxmlformats-officedocument.wordprocessingml.document": true, // .docx
	"application/msword": true, // .doc
	"application/pdf":    true, // .pdf (basic extraction)
	"text/plain":         true, // .txt
	"text/csv":           true, // .csv
	"text/markdown":      true, // .md
	"text/html":          true, // .html
	"application/json":   true, // .json
	"application/xml":    true, // .xml
	"text/xml":           true, // .xml
	"application/rtf":    true, // .rtf
	"text/rtf":           true, // .rtf
}

// IsDocumentType returns true if the MIME type is a document that should be converted to text.
func IsDocumentType(mimeType string) bool {
	return documentMimeTypes[mimeType]
}

// ExtractDocumentText reads a file and extracts its text content.
// For .docx files, it parses the XML structure.
// For text-based files, it reads them directly.
func ExtractDocumentText(filePath string, mimeType string) (string, error) {
	ext := strings.ToLower(filepath.Ext(filePath))

	switch {
	case ext == ".docx" || mimeType == "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
		return extractDocxText(filePath)
	case ext == ".pdf" || mimeType == "application/pdf":
		return extractPdfText(filePath)
	default:
		return extractPlainText(filePath)
	}
}

// ExtractDocumentTextFromBytes extracts text from in-memory file data.
func ExtractDocumentTextFromBytes(data []byte, fileName string, mimeType string) (string, error) {
	ext := strings.ToLower(filepath.Ext(fileName))

	switch {
	case ext == ".docx" || mimeType == "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
		return extractDocxTextFromBytes(data)
	case ext == ".pdf" || mimeType == "application/pdf":
		return "", fmt.Errorf("PDF text extraction from bytes not supported — attach the file path instead")
	default:
		return string(data), nil
	}
}

func extractPlainText(filePath string) (string, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return "", fmt.Errorf("failed to read file: %w", err)
	}
	return string(data), nil
}

func extractDocxText(filePath string) (string, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return "", fmt.Errorf("failed to read docx: %w", err)
	}
	return extractDocxTextFromBytes(data)
}

func extractDocxTextFromBytes(data []byte) (string, error) {
	reader, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return "", fmt.Errorf("failed to open docx as zip: %w", err)
	}

	var documentXML *zip.File
	for _, f := range reader.File {
		if f.Name == "word/document.xml" {
			documentXML = f
			break
		}
	}

	if documentXML == nil {
		return "", fmt.Errorf("word/document.xml not found in docx")
	}

	rc, err := documentXML.Open()
	if err != nil {
		return "", fmt.Errorf("failed to open document.xml: %w", err)
	}
	defer rc.Close()

	xmlData, err := io.ReadAll(rc)
	if err != nil {
		return "", fmt.Errorf("failed to read document.xml: %w", err)
	}

	return parseWordXML(xmlData), nil
}

// parseWordXML extracts text from Word's document.xml, preserving paragraph structure.
func parseWordXML(data []byte) string {
	decoder := xml.NewDecoder(bytes.NewReader(data))
	var paragraphs []string
	var currentParagraph strings.Builder
	inText := false

	for {
		token, err := decoder.Token()
		if err != nil {
			break
		}

		switch t := token.(type) {
		case xml.StartElement:
			switch t.Name.Local {
			case "t": // <w:t> text run
				inText = true
			case "tab": // <w:tab>
				currentParagraph.WriteString("\t")
			case "br": // <w:br>
				currentParagraph.WriteString("\n")
			}
		case xml.EndElement:
			switch t.Name.Local {
			case "t":
				inText = false
			case "p": // end of paragraph
				text := strings.TrimRight(currentParagraph.String(), " ")
				paragraphs = append(paragraphs, text)
				currentParagraph.Reset()
			}
		case xml.CharData:
			if inText {
				currentParagraph.Write(t)
			}
		}
	}

	// Flush any remaining content
	if currentParagraph.Len() > 0 {
		paragraphs = append(paragraphs, currentParagraph.String())
	}

	return strings.Join(paragraphs, "\n")
}

func extractPdfText(filePath string) (string, error) {
	// Basic PDF text extraction — reads raw text streams.
	// For complex PDFs with scanned images, a full PDF library would be needed.
	data, err := os.ReadFile(filePath)
	if err != nil {
		return "", fmt.Errorf("failed to read PDF: %w", err)
	}

	content := string(data)
	var texts []string

	// Extract text between BT (begin text) and ET (end text) operators
	for {
		btIdx := strings.Index(content, "BT")
		if btIdx == -1 {
			break
		}
		etIdx := strings.Index(content[btIdx:], "ET")
		if etIdx == -1 {
			break
		}

		textBlock := content[btIdx : btIdx+etIdx+2]
		// Extract text from Tj and TJ operators
		for _, line := range strings.Split(textBlock, "\n") {
			line = strings.TrimSpace(line)
			if strings.HasSuffix(line, "Tj") {
				text := strings.TrimSuffix(line, "Tj")
				text = strings.TrimSpace(text)
				text = strings.Trim(text, "()")
				if text != "" {
					texts = append(texts, text)
				}
			}
		}
		content = content[btIdx+etIdx+2:]
	}

	if len(texts) == 0 {
		return "", fmt.Errorf("could not extract text from PDF — the file may contain scanned images. Try copying the text manually")
	}

	return strings.Join(texts, "\n"), nil
}
