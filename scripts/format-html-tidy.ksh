#!/bin/ksh

# If we are NOT already running under ksh93, try to re-exec with ksh93.
# If ksh93 is not available, fall back to the base ksh (OpenBSD /bin/ksh).
case "${KSH_VERSION-}" in
  *93*) : ;;  # already ksh93
  *)
    if command -v ksh93 >/dev/null 2>&1; then
      exec ksh93 "$0" "$@"
    elif [ -x /usr/local/bin/ksh93 ]; then
      exec /usr/local/bin/ksh93 "$0" "$@"
    elif command -v ksh >/dev/null 2>&1; then
      exec ksh "$0" "$@"
    elif [ -x /bin/ksh ]; then
      exec /bin/ksh "$0" "$@"
    fi
  ;;
esac

set -u

# Script to format HTML files using tidy
#
# Copyright (c) 2025 David Uhden Collado <david@uhden.dev>
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

# Basic PATH (important when run from cron)
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export PATH

if [ -t 1 ] && [ "${NO_COLOR:-}" != "1" ]; then
  GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; RESET="\033[0m"
else
  GREEN=""; YELLOW=""; RED=""; RESET=""
fi

log()   { print "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[INFO]${RESET} ✅ $*"; }
warn()  { print "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}[WARN]${RESET} ⚠️ $*" >&2; }
error() { print "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${RESET} ❌ $*" >&2; }

ROOT=${1:-$(cd -- "$(dirname -- "$0")/.." && pwd)}

ensure_tidy() {
  if command -v tidy >/dev/null 2>&1; then
    return 0
  fi

  if command -v pkg_add >/dev/null 2>&1; then
    warn "tidy not found; attempting installation with pkg_add ..."
    if pkg_add -v tidy; then
      return 0
    fi
    error "pkg_add failed to install tidy"
  else
    error "tidy is not installed and pkg_add is unavailable"
  fi

  return 1
}

format_html_files() {
  # find on OpenBSD lacks -print0; use newline delim and handle spaces via IFS
  find "$ROOT" -type f -name '*.html' | while IFS= read -r file; do
    tidy -indent -quiet -wrap 80 -utf8 \
      --indent-spaces 2 \
      --tidy-mark no \
      --preserve-entities yes \
      --vertical-space yes \
      -modify "$file" || warn "tidy issues in $file"
  done
}

main() {
  ensure_tidy || exit 1
  format_html_files
}

main "$@"
