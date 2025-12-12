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

// This script provides a fallback for links with target="_blank".
// When a user clicks such a link, ask if they want to open in a new tab.
// If pop-ups are blocked, fall back to same-tab navigation.
document.addEventListener('click', function (event) {
  // Ignore clicks with modifier keys or already-handled events.
  if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) {
    return;
  }

  // Find the nearest anchor element with an href.
  const link = event.target.closest('a[href]');
  if (!link || link.target !== '_blank') {
    return;
  }

  // Prevent default navigation for _blank links.
  event.preventDefault();
  const href = link.href;

  // Ask the user if they want to open in a new tab.
  const openInNewTab = window.confirm('Open this link in a new tab?');
  if (openInNewTab) {
    const opened = window.open(href, '_blank');
    if (!opened) {
      // If pop-up is blocked, navigate in the same tab.
      window.location.href = href;
    }
  } else {
    window.location.href = href;
  }
});