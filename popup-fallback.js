/*!
 * Popup Fallback Script
 *
 * Copyright (c) 2025 The Cyberpunk Handbook Authors
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

// Ask first: open in new tab or same tab for target="_blank" links.
// Avoid opening before the user decides; fall back gracefully if pop-ups are blocked.
document.addEventListener('click', function (event) {
  // Respect modified clicks (Ctrl/Cmd/Shift/Middle) and prior handlers.
  if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) {
    return;
  }

  const link = event.target.closest('a[href]');
  if (!link || link.target !== '_blank') {
    return;
  }

  event.preventDefault();
  const href = link.href;

  const openInNewTab = window.confirm('Open this link in a new tab?');
  if (openInNewTab) {
    const opened = window.open(href, '_blank');
    if (!opened) {
      // Pop-up blocked; fall back to same-tab navigation.
      window.location.href = href;
    }
  } else {
    window.location.href = href;
  }
});
