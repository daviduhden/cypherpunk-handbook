#!/bin/ksh
set -eu

# Script to format HTML files using tidy
#
# Copyright (c) 2025 The Cyberpunk Handbook Authors
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

# Prefer ksh93 when available; fallback to base ksh
if [ -z "${_KSH93_EXECUTED:-}" ] && command -v ksh93 >/dev/null 2>&1; then
    _KSH93_EXECUTED=1 exec ksh93 "$0" "$@"
fi
_KSH93_EXECUTED=1

ROOT=${1:-$(cd -- "$(dirname -- "$0")/.." && pwd)}

ensure_tidy() {
  if command -v tidy >/dev/null 2>&1; then
    return 0
  fi

  if command -v pkg_add >/dev/null 2>&1; then
    print "tidy not found; attempting installation with pkg_add ..." >&2
    if pkg_add -v tidy; then
      return 0
    fi
    print "error: pkg_add failed to install tidy" >&2
  else
    print "error: tidy is not installed and pkg_add is unavailable" >&2
  fi

  return 1
}

ensure_tidy || exit 1

# find on OpenBSD lacks -print0; use newline delim and handle spaces via IFS
find "$ROOT" -type f -name '*.html' | while IFS= read -r file; do
  tidy -indent -quiet -wrap 0 -utf8 \
    --indent-spaces 2 \
    --tidy-mark no \
    --preserve-entities yes \
    --vertical-space yes \
    -modify "$file" || echo "warning: tidy issues in $file" >&2
done
