// @licstart The following is the license notice for the JavaScript code in this file.
// @license SPDX: ISC
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
// @licend The above is the entire license notice for the JavaScript code in this file.

// Attempt to open target="_blank" links; if blocked, fall back to same-tab navigation.
document.addEventListener('click', function (event) {
  const link = event.target.closest('a[href]');
  if (!link) {
    return;
  }

  if (link.target === '_blank') {
    const href = link.href;
    const opened = window.open(href, link.target);
    if (!opened) {
      event.preventDefault();
      window.location.href = href;
    }
  }
});
