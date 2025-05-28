package main

import (
	"fmt"
	"github.com/dhowden/tag"
	"os"
	"path/filepath"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: uzume <directory>")
		os.Exit(1)
	}
	root := os.Args[1]

	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			fmt.Fprintf(os.Stderr, "error accessing path %q: %v\n", path, err)
			return nil
		}

		// Фильтруем только аудиофайлы
		switch filepath.Ext(path) {
		case ".mp3", ".flac", ".m4a", ".ogg":
			f, err := os.Open(path)
			if err != nil {
				fmt.Printf("Failed to open file: %s\n", path)
				return nil
			}
			defer f.Close()

			m, err := tag.ReadFrom(f)
			if err != nil {
				fmt.Printf("Failed to read tags: %s\n", path)
				return nil
			}

			fmt.Printf("File: %s\n", path)
			fmt.Printf("  Title:  %s\n", m.Title())
			fmt.Printf("  Artist: %s\n", m.Artist())
			fmt.Printf("  Album:  %s\n", m.Album())
			fmt.Printf("  Genre:  %s\n", m.Genre())
			fmt.Printf("  Year:   %d\n", m.Year())
			fmt.Println()
		}

		return nil
	})

	if err != nil {
		fmt.Fprintf(os.Stderr, "error walking the path %q: %v\n", root, err)
		os.Exit(1)
	}
}
