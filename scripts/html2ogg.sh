#!/bin/sh
#
# Copyright (c) 2025 David Uhden Collado
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
# -----------------------------
# POSIX-compatible HTML to OGG speech script
# Uses pandoc, espeak-ng, and ffmpeg
# Usage: html2ogg.sh file.html
# -----------------------------

set -e

# -----------------------------
# Dependency checks
# -----------------------------
if ! command -v pandoc >/dev/null 2>&1; then
	echo "❌ pandoc is not installed"
	exit 1
fi

if ! command -v espeak-ng >/dev/null 2>&1; then
	echo "❌ espeak-ng is not installed"
	exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
	echo "❌ ffmpeg is not installed"
	exit 1
fi

# -----------------------------
# Argument check
# -----------------------------
if [ -z "$1" ]; then
	echo "Usage: $0 file.html"
	exit 1
fi

HTML="$1"

if [ ! -f "$HTML" ]; then
	echo "❌ File not found: $HTML"
	exit 1
fi

# -----------------------------
# Language selection
# -----------------------------
echo "Which language do you want the text to be read in?"
echo "1) Spanish (Spain)"
echo "2) English (United Kingdom)"
printf "Choose 1 or 2: "
read -r LANG_OPT

case "$LANG_OPT" in
1)
	VOICE="es-es"
	SPEED=140
	;;
2)
	VOICE="en-gb"
	SPEED=140
	;;
*)
	echo "❌ Invalid option"
	exit 1
	;;
esac

# Output file name: derive from input HTML (e.g. articles/systems.html -> articles/systems.ogg)
OUT="${HTML%.*}.ogg"

# -----------------------------
# Temporary WAV file (POSIX-safe)
# -----------------------------
umask 077
TMP_WAV="/tmp/voice$$.wav"
i=0
while [ -e "$TMP_WAV" ]; do
	i=$((i + 1))
	TMP_WAV="/tmp/voice$$.$i.wav"
done

trap 'rm -f "$TMP_WAV"' EXIT

# -----------------------------
# Conversion pipeline
# -----------------------------
echo "▶️ Converting HTML to audio..."

pandoc "$HTML" -t plain --wrap=none | espeak-ng -v "$VOICE" -s "$SPEED" -p 50 -w "$TMP_WAV"

ffmpeg -y -loglevel error -i "$TMP_WAV" -ac 2 -c:a vorbis -q:a 5 -strict -2 "$OUT"

# -----------------------------
# Split if file exceeds 50 MB
# -----------------------------
MAX_BYTES=$((50 * 1024 * 1024))
OUT_SIZE=$(wc -c <"$OUT" | tr -d ' ')

if [ "$OUT_SIZE" -gt "$MAX_BYTES" ]; then
	if ! command -v ffprobe >/dev/null 2>&1; then
		echo "❌ ffprobe is not installed (required to split large files)"
		exit 1
	fi

	DURATION=$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$OUT")

	# segment_time = duration * max_bytes / out_size, with a safety factor
	SEGMENT_TIME=$(awk -v d="$DURATION" -v max="$MAX_BYTES" -v size="$OUT_SIZE" 'BEGIN { t = d * max / size; t = t * 0.95; if (t < 1) t = 1; printf "%.2f", t }')

	OUT_BASE="${OUT%.*}_part%02d.ogg"
	ffmpeg -y -loglevel error -i "$OUT" -c copy -f segment -segment_time "$SEGMENT_TIME" -reset_timestamps 1 "$OUT_BASE"

	rm -f "$OUT"

	echo "⚠️ Output exceeded 50MB. Split into parts: ${OUT%.*}_part00.ogg, ${OUT%.*}_part01.ogg, ..."
else
	echo "✅ Audio successfully generated: $OUT"
fi
