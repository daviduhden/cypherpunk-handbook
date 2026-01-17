#!/bin/sh

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
# POSIX-compatible SVG to PNG conversion script
# Uses rsvg-convert
# Usage: svg2png.sh directory
# -----------------------------

if ! command -v rsvg-convert >/dev/null 2>&1; then
	echo "❌ rsvg-convert is not installed"
	exit 1
fi

# Exit immediately if a command fails
set -e

# Target width in pixels
WIDTH=500

# Find all SVG files recursively
find . -type f -name '*.svg' -print |
	while IFS= read -r svg; do
		# Build output PNG path (same directory, same base name)
		png=$(printf '%s\n' "$svg" | sed 's/\.svg$/.png/')

		# Skip conversion if PNG already exists
		if [ -e "$png" ]; then
			printf '⏭️ Skipping (already exists): %s\n' "$png"
			continue
		fi

		printf '🖼️ Converting: %s -> %s\n' "$svg" "$png"
		# Convert SVG to PNG using rsvg-convert
		rsvg-convert \
			--width="$WIDTH" \
			--format=png \
			--output="$png" \
			"$svg"
	done
