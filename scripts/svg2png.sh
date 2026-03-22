#!/bin/sh

# Copyright (c) 2025-2026 David Uhden Collado
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
# POSIX-compatible SVG to PNG conversion script
# Uses rsvg-convert
# Usage: svg2png.sh directory
# -----------------------------

# Exit immediately if a command fails
set -e

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "❌ $1 is not installed"
		exit 1
	fi
}

parse_args() {
	DIR=${1:-.}
	if [ ! -d "$DIR" ]; then
		echo "❌ Directory not found: $DIR" >&2
		exit 1
	fi
}

convert_one_svg() {
	svg=$1
	png=$(printf '%s\n' "$svg" | sed 's/\.svg$/.png/')

	if [ -e "$png" ]; then
		printf '⏭️ Skipping (already exists): %s\n' "$png"
		return 0
	fi

	printf '🖼️ Converting: %s -> %s\n' "$svg" "$png"
	rsvg-convert \
		--width="$WIDTH" \
		--format=png \
		--output="$png" \
		"$svg"
}

run_conversion() {
	find "$DIR" -type f -name '*.svg' -print |
		while IFS= read -r svg; do
			convert_one_svg "$svg"
		done
}

main() {
	WIDTH=500
	require_cmd rsvg-convert
	parse_args "$@"
	run_conversion
}

main "$@"
