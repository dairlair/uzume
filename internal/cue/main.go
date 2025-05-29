package cue

import (
	"bufio"
	"fmt"
	"os"
	"regexp"
	"strconv"
	"strings"
)

// Track represents a single track in the CUE sheet
type Track struct {
	Number     int
	Title      string
	Performer  string
	StartTime  string // MM:SS:FF format
	Index      int
	FileOffset int // in samples (calculated from MM:SS:FF)
}

// CueSheet represents the parsed CUE file structure
type CueSheet struct {
	Performer string
	Title     string
	FileName  string
	FileType  string
	Tracks    []Track
}

// ParseCueFile parses a CUE file and returns a CueSheet struct
func ParseCueFile(filename string) (*CueSheet, error) {
	file, err := os.Open(filename)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	sheet := &CueSheet{}
	scanner := bufio.NewScanner(file)
	currentTrack := &Track{}

	// Regex patterns for CUE file lines
	filePattern := regexp.MustCompile(`FILE\s+"(.*?)"\s+(.*?)\s*$`)
	trackPattern := regexp.MustCompile(`TRACK\s+(\d+)\s+(.*?)\s*$`)
	titlePattern := regexp.MustCompile(`TITLE\s+"(.*?)"\s*$`)
	performerPattern := regexp.MustCompile(`PERFORMER\s+"(.*?)"\s*$`)
	indexPattern := regexp.MustCompile(`INDEX\s+(\d+)\s+(\d+):(\d+):(\d+)\s*$`)

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		switch {
		case strings.HasPrefix(line, "FILE"):
			matches := filePattern.FindStringSubmatch(line)
			if len(matches) == 3 {
				sheet.FileName = matches[1]
				sheet.FileType = matches[2]
			}

		case strings.HasPrefix(line, "TRACK"):
			// Save previous track if it exists
			if currentTrack.Number > 0 {
				sheet.Tracks = append(sheet.Tracks, *currentTrack)
			}

			matches := trackPattern.FindStringSubmatch(line)
			if len(matches) >= 2 {
				trackNum, _ := strconv.Atoi(matches[1])
				currentTrack = &Track{Number: trackNum}
				if len(matches) == 3 {
					currentTrack.Title = matches[2]
				}
			}

		case strings.HasPrefix(line, "TITLE"):
			matches := titlePattern.FindStringSubmatch(line)
			if len(matches) == 2 {
				if currentTrack.Number > 0 {
					currentTrack.Title = matches[1]
				} else {
					sheet.Title = matches[1]
				}
			}

		case strings.HasPrefix(line, "PERFORMER"):
			matches := performerPattern.FindStringSubmatch(line)
			if len(matches) == 2 {
				if currentTrack.Number > 0 {
					currentTrack.Performer = matches[1]
				} else {
					sheet.Performer = matches[1]
				}
			}

		case strings.HasPrefix(line, "INDEX"):
			matches := indexPattern.FindStringSubmatch(line)
			if len(matches) == 5 {
				indexNum, _ := strconv.Atoi(matches[1])
				if indexNum == 1 { // We only care about INDEX 01 for track start
					minutes, _ := strconv.Atoi(matches[2])
					seconds, _ := strconv.Atoi(matches[3])
					frames, _ := strconv.Atoi(matches[4])

					currentTrack.StartTime = fmt.Sprintf("%02d:%02d:%02d", minutes, seconds, frames)
					currentTrack.Index = indexNum

					// Convert to samples (assuming 44.1kHz, 75 frames per second)
					totalFrames := (minutes * 60 * 75) + (seconds * 75) + frames
					currentTrack.FileOffset = totalFrames * (44100 / 75)
				}
			}
		}
	}

	// Add the last track
	if currentTrack.Number > 0 {
		sheet.Tracks = append(sheet.Tracks, *currentTrack)
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}

	return sheet, nil
}
