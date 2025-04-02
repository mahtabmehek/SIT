#!/bin/bash

# Ensure necessary directories exist
mkdir -p logs transcoded

BITRATE="$1"
VIDEO="$2"

if [ -z "$BITRATE" ] || [ -z "$VIDEO" ]; then
  echo "Usage: $0 <bitrate> <video>"
  exit 1
fi

echo "[*] Transcoding $VIDEO at ${BITRATE}Mbps"

INPUT_FILE="resized_videos/${VIDEO}.mp4"
OUTPUT_FILE="transcoded/${VIDEO}_${BITRATE}Mbps.mp4"

# Perform transcoding
ffmpeg -y -i "$INPUT_FILE" -b:v ${BITRATE}M -bufsize ${BITRATE}M -maxrate ${BITRATE}M \
  -c:v libx264 -preset fast -c:a aac -b:a 192k "$OUTPUT_FILE"

echo "[✓] Done: $VIDEO @ ${BITRATE}Mbps"
