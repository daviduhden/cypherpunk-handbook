#!/bin/sh

# Copyright (c) 2025-2026, David Uhden Collado
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
# DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA
# OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
# TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
# -----------------------------
# POSIX-compatible HTML to OGG speech script
# Uses pandoc, espeak-ng, and ffmpeg
# Usage: html2ogg.sh file.html
# -----------------------------

set -e

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "[ERROR] $1 is not installed" >&2
		exit 1
	fi
}

check_dependencies() {
	require_cmd mktemp
	require_cmd pandoc
	require_cmd espeak-ng
	require_cmd ffmpeg
}

parse_args() {
	if [ $# -lt 1 ]; then
		echo "Usage: $0 file.html" >&2
		exit 1
	fi

	HTML=$1
	if [ ! -f "$HTML" ]; then
		echo "[ERROR] File not found: $HTML" >&2
		exit 1
	fi
}

select_language() {
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
		echo "[ERROR] Invalid option" >&2
		exit 1
		;;
	esac
}

create_temp_wav() {
	# mktemp creates the file with an unpredictable name and mode 0600,
	# using O_EXCL, which avoids races and symlink attacks.
	TMP_WAV=$(mktemp "${TMPDIR:-/tmp}/voice-XXXXXX") || {
		echo "[ERROR] Could not create temporary file" >&2
		exit 1
	}
}

convert_html_to_ogg() {
	# The destination is adjacent to the source; ffmpeg's -y option below
	# intentionally replaces an existing recording with the same basename.
	OUT="${HTML%.*}.ogg"
	echo "Converting HTML to audio..."
	# Run pandoc as a separate, checked command so a text
	# extraction failure aborts the conversion instead of feeding
	# empty input to espeak-ng (POSIX sh has no pipefail).
	text=$(pandoc "$HTML" -t plain --wrap=none)
	printf '%s\n' "$text" |
		espeak-ng -v "$VOICE" -s "$SPEED" \
			-p 50 -w "$TMP_WAV"
	ffmpeg -y -loglevel error -i "$TMP_WAV" \
		-ac 2 -c:a vorbis -q:a 5 \
		-strict -2 "$OUT"
	echo "[OK] Audio successfully generated: $OUT"
}

cleanup() {
	rm -f "$TMP_WAV"
}
trap cleanup EXIT HUP INT TERM

main() {
	check_dependencies
	parse_args "$@"
	select_language
	create_temp_wav
	convert_html_to_ogg
}

main "$@"
