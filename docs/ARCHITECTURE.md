# Cypherpunk Handbook architecture and maintenance map

## Site model

The handbook is a static documentary site. Published pages and articles are
hand-authored HTML and are served as committed; there is no Markdown content
source, template engine, package manager, or site build step. The article pages
are the source for feed metadata. `index.html` is a separately curated listing,
and `data/articles.json` is a hand-maintained index validated against article
files. The template under `templates/` is a manual reference, not a rendering
input. Perl scripts generate feeds and the sitemap. A read-only GitHub Actions PR
workflow validates agent knowledge; a separate archive workflow creates
signed source archives, not published pages.

## Dependency map

```text
articles/*.html ──metadata and content──> scripts/rebuild-feeds.pl ──> feeds/articles.xml
       │                                  └── scripts/rebuild-sitemap.pl ──> sitemap.xml
       ├──> data/articles.json ──checked against article filenames and <h1> by t/integrity.t
       └──> index.html ──hand-curated listing, optionally edited by update-articles.pl

published HTML ──loads──> styles.css
index.html ──includes JSON-LD data only; there are no standalone browser JS modules

scripts/validate-agent-knowledge.py ──read-only policy and instruction gate
scripts/*.pl and scripts/*.sh ──manual site maintenance and validation
.github/workflows/agent-knowledge-validation.yml ──read-only PR tests and range gate
.github/workflows/archive.yml ──daily/manual archive, signing, history rewrite, force-push
```

The feed generator recursively scans `articles/**/*.html` except
`articles/index.html`. It reads language, the article heading, description, and
`<time datetime>`, normalizes text/entity data, and sorts by timestamp descending
then slug ascending. It uses root-relative item links and GUIDs so the feed does
not bind to one mirror. If a date is absent or invalid, the script falls back
to file modification time, which is not reproducible across arbitrary copies;
keep valid authored dates. The generator rewrites the whole feed while
preserving only the channel title, link, and description. Atomic replacement
preserves the existing file mode and avoids exposing partially written output.

The sitemap generator scans public `.html` files, excludes `archive/` and
`templates/`, maps index documents to directory URLs, sorts locations, and uses
the fixed `https://handbook.uhden.dev` origin. It deliberately emits no
fabricated modification date. Do not edit generated feed or sitemap files
directly.

`update-articles.pl` inserts one link into an existing subsection of
`index.html`; it does not create an article or update JSON/feed metadata.
`update-feeds.pl` is interactive and can invoke the feed rebuild when that
script is executable, so the article page remains the authoritative metadata
source. For normal content maintenance, update the article, JSON registry, and
index, then regenerate derived outputs.

## CSS, accessibility, and browser surface

`styles.css` is a hand-maintained stylesheet. Its root custom properties define
the dark palette, shared dimensions, typography/layout tokens, borders, shadows,
and a two-color focus ring. The same general component system styles article
content, tables, code, the table of contents, and the home page's article grid.
The TOC uses CSS counters with depth classes supplied by the HTML; changing the
counter resets or class structure can renumber descendants. At `60em`, the TOC
becomes a single column and table wrappers use their responsive behavior. The
article grid uses `auto-fit` and a minimum column width to determine when to
wrap; at `48em`, its outer panel also tightens its padding. Preserve these
breakpoints and the wrapper classes around wide tables.

Images use fluid sizing and the QR image is capped relative to content width.
The stylesheet includes visible keyboard focus, reduced-motion rules, and
print/forced-colors output. These are behavior-affecting design constraints,
not decorative extras. Existing CSS alone does not establish a WCAG conformance
claim; no contrast audit or browser matrix is defined in this repository.

The home page's `application/ld+json` block is structured metadata and is not
executed as JavaScript. There are no separate JavaScript modules, DOM event
handlers, storage calls, or client fetches in the tracked site. Pages use local
assets and stylesheet references. No CSP, cookie policy, server configuration,
or HTTP security-header policy is stored here, so hosting behavior cannot be
verified from the repository.

## Configuration and automation

| File | Consumer and effect |
| --- | --- |
| `dprint.json` | Pins formatter plugins and sets an 80-column/LF style. The JSON parser does not support comments. |
| `.stylelintrc.json` | Enables CSS syntax and consistency rules; it allows adjacent fallback declarations with different syntax. JSON does not support comments. |
| `.htmltest.yml` | Enables offline document, link, anchor, image, and metadata checks; external/mail/telephone checks are disabled and special schemes are ignored. |
| `.perlcriticrc` | Runs Perl::Critic at severity 3 with explicitly justified policy exceptions. |
| `.gitattributes` | Routes archive tarballs through Git LFS without text conversion. |
| `.gitignore` | Ignores temporary validation artifacts under `tmp/`. |
| `robots.txt` | Permits crawler access and advertises the HTTPS sitemap; it does not restrict direct access. |
| `scripts/openbsd-tools.txt` | Informational mapping from tools to OpenBSD ports; scripts do not parse it. |
| `data/articles.json` | Maps each article key to filename, first-publication date, and exact English `<h1>` title. `pubdate` is not the last-modified `<time>` used by the feed. |
| `.github/workflows/agent-knowledge-validation.yml` | Runs the shared contract tests and range gate on pull requests with read-only repository permission. |
| `.github/workflows/archive.yml` | Runs on a daily schedule or manual dispatch. It creates a tarball, checksum, and signature, then rewrites history and force-pushes `main`. It does not test, build, or deploy the site. |

The archive workflow retrieves `signify` over the network (with clearnet/Tor
and package fallbacks), uses the `SIGNIFY_KEY` secret to sign the checksum, and
has repository write permission. These are workflow-side effects; the workflow
is not a local build command and should not be triggered for documentation work.
The repository contains no hosting, server, CSP, or response-header
configuration.

The archive omits GitHub and maintainer documentation, VCS metadata, agent
instructions, development settings, test and cache directories, and known
editor backup files. These remain tracked in GitHub. It does not exclude
Markdown or hidden files broadly; public resources such as article metadata,
feeds, images, `robots.txt`, and `sitemap.xml` stay in the bundle. The OpenBSD
sync script applies the same internal-file policy and removes known stale
exclusions from the document root while preserving its active `.sync.lock`.

## Maintenance boundaries

- Preserve article metadata consistency: every article is represented in
  `data/articles.json`, every entry names a real file, and the stored title
  matches the article `<h1>`.
- Keep `pubdate` (first publication) distinct from the article `<time>` date
  (last modification and feed date).
- Keep feed item URLs and GUIDs root-relative for mirror portability.
- Do not edit generated feeds, sitemap, signed archives, or public-key
  artifacts by hand.
- Keep page stylesheets and image references local, use fluid images, and
  preserve skip links, semantic tables, focus treatment, responsive table
  wrappers, reduced motion, and forced-colors behavior.
- `validate-website.pl` defaults to rewriting files. Use `--check` or
  `--check-all` for read-only validation; `--check-all` can include tests and
  optional linters.
- `t/00-syntax.t` checks script syntax; `t/integrity.t` reads live article and
  generated-file relationships; generator and interactive-helper tests use
  temporary fixtures; `t/reproducible.t` regenerates outputs in a temporary
  repository copy. `t/links.t` requires `tidy` and skips when it is unavailable.
- The archive workflow rewrites repository history and force-pushes `main`.
