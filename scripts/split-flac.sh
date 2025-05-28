#!/usr/bin/env bash

# FLAC Cutter v1.0 — bash tool for splitting FLAC+CUE into tracks with tags
# Software requirements: cuetools shntool flac
# To install on linux run `sudo apt install cuetools shntool flac`,
# on MacOS run `brew install cuetools shntool flac`.

set -euo pipefail
IFS=$'\n\t'

# Global config
DRY_RUN=false
MUSIC_DIR="."
TAGGER=""

# ------------------------
# Logging and Errors
# ------------------------

log() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

error_exit() {
  echo "[ERROR] $*" >&2
  exit 1
}

# ------------------------
# Utilities
# ------------------------

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

detect_tagger() {
  if command_exists cuetag; then
    # Usually on Linux
    TAGGER="cuetag"
  elif command_exists cuetag.sh; then
    # This script available on MacOS after `cuetools` installation.
    TAGGER="cuetag.sh"
  else
    error_exit "Neither cuetag nor cuetag.sh found in PATH"
  fi
}

# ------------------------
# Checks
# ------------------------

verify_prereqs() {
  log "Checking prerequisites..."

  for cmd in cuebreakpoints shnsplit flac; do
    if ! command_exists "$cmd"; then
      error_exit "Missing required command: $cmd"
    fi
  done

  detect_tagger
  log "Using tagger: $TAGGER"

  log "All required commands are available."
}

# ------------------------
# Album Processing
# ------------------------

process_album() {
  local cue_file="$1"
  local dir
  dir=$(dirname "$cue_file")
  local base
  base=$(basename "$cue_file" .cue)
  local flac_file="$dir/$base.flac"

  if [[ ! -f "$flac_file" ]]; then
    warn "FLAC file not found for cue: $cue_file"
    return
  fi

  log "Processing album: $base"

  if [[ "$DRY_RUN" = true ]]; then
    log "[DRY RUN] Would split: $flac_file"
    return
  fi

  split_album "$cue_file" "$flac_file"
  tag_tracks "$cue_file"
  organize_tracks "$dir"
}

split_album() {
  local cue_file="$1"
  local flac_file="$2"

  log "Generating breakpoints from cue..."
  cuebreakpoints "$cue_file" > breakpoints.txt

  log "Splitting FLAC..."
  shnsplit -f "$cue_file" -o flac -t "%n - %t" "$flac_file"
}

tag_tracks() {
  local cue_file="$1"

  log "Tagging split tracks with cue metadata using [$TAGGER] as tagging tool..."
  "$TAGGER" "$cue_file" split-track*.flac
}

organize_tracks() {
  local dir="$1"

  mkdir -p "$dir/split"
  mv split-track*.flac "$dir/split/" || warn "No split tracks found to move."
  rm -f breakpoints.txt
}

# ------------------------
# Main
# ------------------------

main() {
  parse_args "$@"

  verify_prereqs

  log "Searching for .cue files in: $MUSIC_DIR"

  local cue_files=()
  while IFS= read -r -d '' cue_file; do
    cue_files+=("$cue_file")
  done < <(find "$MUSIC_DIR" -type f -iname "*.cue" -print0)

  if [[ ${#cue_files[@]} -eq 0 ]]; then
    warn "No .cue files found."
    return
  fi

  for cue_file in "${cue_files[@]}"; do
    process_album "$cue_file"
  done

  log "Done!"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -n|--dry-run)
        DRY_RUN=true
        ;;
      -d|--dir)
        MUSIC_DIR="$2"
        shift
        ;;
      -h|--help)
        echo "Usage: $0 [-n|--dry-run] [-d|--dir <music-dir>]"
        exit 0
        ;;
      *)
        error_exit "Unknown argument: $1"
        ;;
    esac
    shift
  done
}

main "$@"
