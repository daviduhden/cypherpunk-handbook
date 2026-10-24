---
name: references-and-attribution
description: Add and preserve citations, permanent links, quotations, image credits, copyright notices, and license exceptions in the handbook without inventing attribution or altering signed archives.
---

# References and attribution

## When to use

Use this skill when a task adds or changes:

- A citation, footnote, reference list, or external link.
- A quotation, paraphrase, or attributed position.
- An image, diagram, audio file, or other third-party asset.
- A copyright line, license notice, or `EXCEPTIONS:` block.
- A link to the signed archive, a mirror, a feed, or a canonical page.

Use `threat-model-and-fact-check` to decide whether a source supports a claim.
This skill governs how the source and its terms are recorded.

## Licensing baseline

- `license.html` contains the site's own terms: a broad authorization limited
  to content obtained within the domains listed on the home page, alongside an
  "All Rights Reserved" notice. Do not rewrite or simplify that text.
- `styles.css` and the scripts listed in `license.html` are separately
  ISC-like; their headers are in the files. Do not relicense them or remove
  their headers.
- `contribute.html` requires all contributions to comply with `license.html`.
  Content not covered by that license needs an explicit `EXCEPTIONS:` notice
  at the beginning of the file, naming the asset and its license or permission.
- There is no repository-wide image credit file, and published articles
  currently carry no image credits. Do not invent one. If you add a
  third-party asset, obtain and record its actual license and attribution.
- The archive public key is a `signify` key and is separate from the PGP key on
  `contact.html`. Do not conflate them.

## Procedure

1. **Inventory the local convention.** Read the target article's existing
   references, inline links, blockquotes, and footer. Match the local format
   (numbered list, unnumbered list, inline link, or `Further reading`) instead
   of imposing a new citation system.
2. **Decide what needs attribution.** Direct quotations, statistics, product
   claims, historical assertions, third-party images, and controversial
   positions need a source. Common knowledge and the author's clearly labeled
   opinion do not.
3. **Choose a stable link.** Prefer, in order:
   - official versioned documentation, man pages, standards, or release notes;
   - tag, commit, or permalink URLs for source code;
   - stable advisory or CVE records;
   - an archived copy only when the original is gone, clearly labeled as such.
   Avoid search-result pages, tracking parameters, and unversioned "latest"
   URLs when a stable alternative exists.
4. **Record source metadata.** Capture author or publisher, title, date or
   version, URL, and access date. Put the access date in working notes or a
   visible "as of" statement when the claim is time-sensitive.
5. **Attribute quotations.** Use `<blockquote>` with `<cite>` where the markup
   supports it, or attribute in the surrounding prose. Identify the speaker and
   the context. Link the actual message, document, or page rather than a
   secondary summary.
6. **Handle translations and pseudonyms.** Preserve the author's chosen name
   or pseudonym exactly. If you translate a quotation, say so and link the
   original.
7. **Add media correctly.** Store assets under `images/` or the existing
   structure, optimize them, and record the real license and credit. Do not
   copy an image from a search engine or assume that a project logo is
   unrestricted.
8. **Preserve copyright and canonical identity.** Keep footer copyright text,
   the `LICENSE` link, the article byline, the canonical URL, and feed GUIDs.
   Do not "modernize" the site license.
9. **Do not touch the signed archive.** `archive/cypherpunk-handbook.tar.gz`,
   `.sha256`, `.sig`, and `.pub` are produced by CI. The signature covers the
   checksum file, not the tarball. If you document verification, use the
   commands in `contribute.html` and do not claim you re-signed anything.
10. **Validate links offline first.** Use the repository's offline checks
    before considering any network request.

## Validation

- Every new citation has a title, publisher/author, URL, and date or version.
- Every quotation is attributable and not truncated in a misleading way.
- Canonical URLs still use the published origin; feed links and GUIDs remain
  root-relative.
- Internal links and anchors resolve. `htmltest -c .htmltest.yml` checks
  internal links, anchors, images, and metadata offline.
- `git diff --check` passes, and no copyright, license, or attribution text was
  removed accidentally.
- Any `EXCEPTIONS:` block appears at the beginning of the file and names the
  asset and license.
- No credentials, personal data, or private contact details were added beyond
  what the project already publishes.

## Link-checking boundaries

- `.htmltest.yml` deliberately sets `CheckExternal: false` and ignores
  `onion`, `i2p`, `mailto:`, `tel:`, `bitcoin:`, and `monero:` URLs.
- `lychee`, when invoked by `validate-website.pl --check-all`, runs with
  `--offline`.
- External URLs are contacted only when `--check-links` and
  `--check-links-external` are both supplied. Do not enable external checks
  without explicit approval; onion and I2P links are not reachable on the
  clearnet.
- A passing link checker does not prove that a source supports the claim.

## Common problems

- **Link rot.** A live URL today may disappear. Prefer permanent identifiers
  and record access dates.
- **Replacing a permanent link with a search page.** This destroys
  verifiability.
- **Unsourced blockquotes.** A quote without a speaker or link is not
  attribution.
- **Invented credits.** Do not assign a license or author to an image merely
  because it appears on the site.
- **License drift.** Adding a CC or MIT notice to site prose changes the
  project's licensing story without authorization.
- **Removing the "All Rights Reserved" line.** It coexists with the broad
  grant; preserve both.
- **Changing a feed GUID.** GUIDs are stable identifiers; keep
  `/articles/<slug>.html` unchanged.
- **Editing signed artifacts.** Manual changes break the checksum/signature
  relationship and are overwritten by CI.
- **Attributing to the wrong identity.** Keep pseudonyms and real names
  distinct, and do not infer an identity from an email address.

## References

- `AGENTS.md` — repository safety and editorial rules.
- `license.html` — site terms and separately licensed files.
- `contribute.html` — `EXCEPTIONS:` format, citation guidance, metadata
  hygiene, and archive verification commands.
- `.htmltest.yml` — offline link, anchor, image, and metadata checks.
- `articles/c-language.html` — numbered reference list example.
- `articles/searxng-on-openbsd.html` — unnumbered references and version
  caveats.
- `articles/openbsd-hardening.html` — "Further reading" example.
- `archive/cypherpunk-handbook.pub` and `archive/*.sha256` — archive
  verification artifacts; do not edit.
