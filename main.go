package main

import (
	"fmt"
	"github.com/dairlair/uzume/internal/cue"
	"github.com/dhowden/tag"
	"os"
	"path/filepath"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: cueparser <cuefile.cue>")
		return
	}

	cueSheet, err := cue.ParseCueFile(os.Args[1])
	if err != nil {
		fmt.Printf("Error parsing CUE file: %v\n", err)
		return
	}

	fmt.Printf("Album: %s\n", cueSheet.Title)
	fmt.Printf("Performer: %s\n", cueSheet.Performer)
	fmt.Printf("Audio File: %s (%s)\n", cueSheet.FileName, cueSheet.FileType)
	fmt.Println("\nTracks:")
	for _, track := range cueSheet.Tracks {
		fmt.Printf("%02d. %s - %s (starts at %s, offset %d samples)\n",
			track.Number,
			track.Performer,
			track.Title,
			track.StartTime,
			track.FileOffset,
		)
	}
}

func mainShowTags() {
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
