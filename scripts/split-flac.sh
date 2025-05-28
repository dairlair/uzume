#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

log() {
  echo -e "[INFO] $*"
}

err() {
  echo -e "[ERROR] $*" >&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  err "Usage: $0 <directory_with_cue_and_flac>"
fi

album_dir="$1"

if [ ! -d "$album_dir" ]; then
  err "Provided path is not a directory: $album_dir"
fi

cue_file=$(find "$album_dir" -maxdepth 1 -iname "*.cue" | head -n 1)
if [ -z "$cue_file" ]; then
  err "No .cue file found in: $album_dir"
fi

# Находим имя FLAC файла из cue
flac_file=$(grep '^FILE' "$cue_file" | sed -E 's/^FILE "(.*)" WAVE/\1/')
full_flac_path="$album_dir/$flac_file"

if [ ! -f "$full_flac_path" ]; then
  err "FLAC file not found: $full_flac_path"
fi

log "Using CUE: $cue_file"
log "Using FLAC: $full_flac_path"

# Выходная директория
output_dir="$album_dir/split"
mkdir -p "$output_dir"

# Получаем треклист: трек|название|время
tracklist=$(cueprint -d '%n|%t|%T\n' "$cue_file")

track_count=$(echo "$tracklist" | wc -l)
log "Found $track_count tracks"

i=1
while IFS='|' read -r track_num title start_time; do
  next_line=$(echo "$tracklist" | sed -n "$((i + 1))p" || true)
  end_time=""
  if [ -n "$next_line" ]; then
    end_time=$(echo "$next_line" | cut -d'|' -f3)
  fi

  # Сделаем имя безопасным
  safe_title=$(echo "$title" | iconv -c -t ascii//TRANSLIT | tr -cd '[:alnum:] _-' | tr ' ' '_')
  output_file="$output_dir/${track_num}_${safe_title}.flac"

  log "Extracting track $track_num: $title"

  ffmpeg -hide_banner -loglevel error -i "$full_flac_path" \
    -ss "$start_time" ${end_time:+-to "$end_time"} \
    -c copy "$output_file"

  ((i++))
done <<< "$tracklist"

log "All tracks extracted to: $output_dir"
