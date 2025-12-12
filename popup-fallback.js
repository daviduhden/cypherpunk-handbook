/*!
 * Popup Fallback Script
 *
 * Copyright (c) 2025 David Uhden Collado <david@uhden.dev>
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

(() => {
  'use strict';

  // Behavior toggles
  const ONLY_EXTERNAL_LINKS = false; // set true if you only want questions for external domains
  const CONFIRM_ONCE_PER_SESSION = true; // remember user's choice for the session

  const SESSION_KEY = 'popupFallbackChoice'; // "newtab" | "sametab" | "ask"
  const ASK = 'ask';

  function getDocLang2() {
    const lang =
      document.documentElement.getAttribute('lang') ||
      document.documentElement.lang ||
      navigator.language ||
      '';
    return String(lang).slice(0, 2).toLowerCase();
  }

  function isExternalUrl(url) {
    return url && url.origin && url.origin !== window.location.origin;
  }

  function getChoice() {
    if (!CONFIRM_ONCE_PER_SESSION) return ASK;
    try {
      return sessionStorage.getItem(SESSION_KEY) || ASK;
    } catch {
      return ASK;
    }
  }

  function setChoice(choice) {
    if (!CONFIRM_ONCE_PER_SESSION) return;
    try {
      sessionStorage.setItem(SESSION_KEY, choice);
    } catch {
      /* ignore */
    }
  }

  function message() {
    const isEs = getDocLang2() === 'es';
    return isEs
      ? '¿Abrir este enlace en una pestaña nueva?'
      : 'Open this link in a new tab?';
  }

  function openSameTab(url) {
    // Using assign() preserves normal navigation semantics
    window.location.assign(url.href);
  }

  function tryOpenNewTab(url, link) {
    // Security: ensure noopener/noreferrer in the opened tab if possible.
    // (We also set rel on the link as a best-effort, without mutating markup permanently.)
    const rel = (link.getAttribute('rel') || '').toLowerCase();
    if (!rel.includes('noopener') || !rel.includes('noreferrer')) {
      // Keep existing rel tokens, add missing ones
      const tokens = new Set(rel.split(/\s+/).filter(Boolean));
      tokens.add('noopener');
      tokens.add('noreferrer');
      link.setAttribute('rel', Array.from(tokens).join(' '));
    }

    const opened = window.open(url.href, '_blank', 'noopener,noreferrer');
    if (!opened) return false;

    // Some browsers may ignore features; best-effort hardening:
    try { opened.opener = null; } catch { /* ignore */ }

    return true;
  }

  // Capture phase helps intercept before other handlers that might navigate.
  document.addEventListener(
    'click',
    (event) => {
      // Ignore already-handled events and non-primary clicks / modifier keys.
      if (
        event.defaultPrevented ||
        event.button !== 0 ||
        event.metaKey ||
        event.ctrlKey ||
        event.shiftKey ||
        event.altKey
      ) {
        return;
      }

      const link = event.target && event.target.closest ? event.target.closest('a[href]') : null;
      if (!link) return;

      // Only handle target=_blank links (as original script intends)
      if (String(link.target).toLowerCase() !== '_blank') return;

      // Ignore downloads and hash-only navigation
      if (link.hasAttribute('download')) return;

      // Resolve URL safely (supports relative href)
      let url;
      try {
        url = new URL(link.getAttribute('href'), window.location.href);
      } catch {
        return; // malformed URL
      }

      // Optional: only question for external links
      if (ONLY_EXTERNAL_LINKS && !isExternalUrl(url)) return;

      // Prevent default _blank navigation.
      event.preventDefault();

      const choice = getChoice();
      if (choice === 'newtab') {
        if (!tryOpenNewTab(url, link)) openSameTab(url);
        return;
      }
      if (choice === 'sametab') {
        openSameTab(url);
        return;
      }

      const openInNewTab = window.confirm(message());
      setChoice(openInNewTab ? 'newtab' : 'sametab');

      if (openInNewTab) {
        if (!tryOpenNewTab(url, link)) openSameTab(url);
      } else {
        openSameTab(url);
      }
    },
    true
  );
})();