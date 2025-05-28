#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Global config
DRY_RUN=false
MUSIC_DIR="."
TAGGER=""
TMP_WAV="temp_input.wav"

# Logging
log()    { printf "\033[1;32m[INFO]\033[0m %s\n" "$*"; }
warn()   { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
error()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*"; }
error_exit() { error "$1"; exit 1; }

# Command checker
command_exists() { command -v "$1" >/dev/null 2>&1; }

detect_tagger() {
  if command_exists cuetag; then
    TAGGER="cuetag"
  elif command_exists cuetag.sh; then
    TAGGER="cuetag.sh"
  else
    error_exit "Neither cuetag nor cuetag.sh found in PATH"
  fi
}

verify_prereqs() {
  log "Checking prerequisites..."
  for cmd in cuebreakpoints shnsplit sox flac; do
    if ! command_exists "$cmd"; then
      error_exit "Missing required command: $cmd"
    fi
  done
  detect_tagger
  log "Using tagger: $TAGGER"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--dir)
        MUSIC_DIR="$2"
        shift 2
        ;;
      -n|--dry-run)
        DRY_RUN=true
        shift
        ;;
      -h|--help)
        echo "Usage: $0 [-d music_dir] [-n]"
        exit 0
        ;;
      *)
        error_exit "Unknown argument: $1"
        ;;
    esac
  done
}

split_tracks() {
  local cue_file="$1"
  local flac_file="$2"

  log "Generating breakpoints from cue..."
  cuebreakpoints "$cue_file" > split-points.tmp

  log "Converting FLAC to WAV via sox..."
  if [ "$DRY_RUN" = true ]; then
    log "[DRY RUN] Would convert: $flac_file → $TMP_WAV"
  else
    sox "$flac_file" "$TMP_WAV" || error_exit "sox conversion failed"
  fi

  log "Splitting WAV..."
  if [ "$DRY_RUN" = true ]; then
    log "[DRY RUN] Would split: $TMP_WAV"
  else
    shnsplit -f "$cue_file" -o flac "$TMP_WAV" || error_exit "shnsplit failed"
  fi

  log "Cleaning up..."
  [ "$DRY_RUN" = false ] && rm -f split-points.tmp "$TMP_WAV"
}

tag_tracks() {
  local cue_file="$1"

  log "Tagging split tracks using $TAGGER..."
  if [ "$DRY_RUN" = true ]; then
    log "[DRY RUN] Would tag with: $TAGGER $cue_file split-track*.flac"
  else
    "$TAGGER" "$cue_file" split-track*.flac || warn "Tagging failed"
  fi
}

process_album() {
  local cue_file="$1"
  local dir
  dir="$(dirname "$cue_file")"
  local flac_file

  flac_file=$(find "$dir" -maxdepth 1 -iname "*.flac" | head -n 1)
  if [[ ! -f "$flac_file" ]]; then
    warn "No FLAC file found in $dir"
    return
  fi

  local wav_file="$dir/temp_input.wav"

  log "Processing: $(basename "$dir")"
  log "Converting FLAC to WAV..."

  if [[ "$DRY_RUN" == true ]]; then
    log "[DRY RUN] ffmpeg -i \"$flac_file\" → \"$wav_file\""
  else
    ffmpeg -y -i "$flac_file" -acodec pcm_s16le "$wav_file" >/dev/null 2>&1 || err "ffmpeg failed"
  fi

  log "Generating split points..."
  cuebreakpoints "$cue_file" > "$dir/split-points.tmp"

  log "Splitting WAV into tracks..."
  if [[ "$DRY_RUN" == true ]]; then
    log "[DRY RUN] shnsplit -f \"$cue_file\" -o flac \"$wav_file\""
  else
    (
      cd "$dir"
      shnsplit -f "$(basename "$cue_file")" -o flac "$(basename "$wav_file")" || err "shnsplit failed"
    )
  fi

  log "Applying tags to split tracks..."
  if [[ "$DRY_RUN" == true ]]; then
    log "[DRY RUN] cuetag \"$cue_file\" split-track*.flac"
  else
    (
      cd "$dir"
      cuetag "$(basename "$cue_file")" split-track*.flac || warn "Tagging failed"
    )
  fi

  log "Cleaning up..."
  [[ "$DRY_RUN" == false ]] && rm -f "$wav_file" "$dir/split-points.tmp"
}

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

main "$@"
