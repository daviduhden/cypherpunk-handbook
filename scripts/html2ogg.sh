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
	SPEED=145
	OUT="output_es.ogg"
	;;
2)
	VOICE="en-gb"
	SPEED=140
	OUT="output_en.ogg"
	;;
*)
	echo "❌ Invalid option"
	exit 1
	;;
esac

# -----------------------------
# Temporary WAV file
# -----------------------------
TMP_WAV=$(mktemp /tmp/voiceXXXXXX.wav)

# -----------------------------
# Conversion pipeline
# -----------------------------
echo "▶️ Converting HTML to audio..."

pandoc "$HTML" -t plain --wrap=none | espeak-ng -v "$VOICE" -s "$SPEED" -p 50 -w "$TMP_WAV"

ffmpeg -y -loglevel error -i "$TMP_WAV" -c:a libvorbis -q:a 5 "$OUT"

# -----------------------------
# Cleanup
# -----------------------------
rm -f "$TMP_WAV"

echo "✅ Audio successfully generated: $OUT"
