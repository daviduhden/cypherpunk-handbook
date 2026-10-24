# AGENTS.md

Instructions for agents working in The Cypherpunk Handbook repository.

## Project

The Cypherpunk Handbook is a static documentary website about security,
privacy, and anonymity. Published pages are hand-authored HTML. There is no
Markdown source for site content and no static-site generator, package manager,
Makefile, or build step. Perl scripts generate the feeds and sitemap and
validate the site; a GitHub Actions workflow archives and signs the repository.

Write documentation and code comments in U.S. English. Keep article prose in
the voice and register the author chose.

## Architecture and sources of truth

| Path | Role | Edit directly? |
| --- | --- | --- |
| `articles/*.html` | Hand-authored articles; source of truth for content and article metadata | Yes |
| `index.html` | Hand-curated article listing | Yes, or via `scripts/update-articles.pl` |
| `data/articles.json` | Hand-maintained index: filename, publication date, title | Yes |
| `templates/articles.html` | Manual reference page, not a build input | Only as documentation |
| `styles.css`, `images/` | Site styling and local assets | Yes, when the task requires it |
| `feeds/articles.xml` | Generated from article HTML by `scripts/rebuild-feeds.pl` | No: regenerate |
| `sitemap.xml` | Generated from public HTML by `scripts/rebuild-sitemap.pl` | No: regenerate |
| `archive/` | CI-produced tarball, checksum, signature, public key | No: never edit |
| `scripts/` | Perl/shell maintenance and validation tools | Yes, when the task requires it |
| `t/` | Perl regression tests (`Test::More`/`prove`) | Yes, when the task requires it |

Article HTML is the source. Do not introduce Markdown as a site source, a
generator, or a template engine, and do not assume one exists.
`data/articles.json` is not generated; `t/integrity.t` requires every article
to be listed, every listed file to exist, and each `title_en`/`title_es` to
match the page `<h1>`.

`data/articles.json`'s `pubdate` is the publication date. An article's
`<time datetime="...">` is its last-modified date and is what the feed uses.
Do not "sync" these fields.

## Verified commands

Run commands from the repository root. There is no build target.

| Kind | Command | Notes |
| --- | --- | --- |
| Tests | `prove t` | Offline; isolated fixtures. `t/links.t` skips without `tidy`. |
| Broadest gate | `perl scripts/validate-website.pl --check-all` | Implies `--check` and internal link checking; runs `prove` plus optional linters. Requires `tidy`, `xmllint`, `dprint`, and `jq` for present file types. Does not enable spelling or external-link checks. |
| Format/validate only | `perl scripts/validate-website.pl --check` | Read-only for target files; may create temp reports, and dprint may resolve plugins over the network. |
| Generate feeds | `perl scripts/rebuild-feeds.pl` | Rewrites `feeds/articles.xml` (or `blog.xml` if present). Keep committed URLs root-relative; do not use `--base-url` for committed feeds. |
| Generate sitemap | `perl scripts/rebuild-sitemap.pl` | Rewrites `sitemap.xml` from public HTML, excluding `archive/`, `templates/`, and generated directories. |
| Add index entry | `perl scripts/update-articles.pl` | Interactive; writes only `index.html`; does not create the article. |
| Insert feed item | `perl scripts/update-feeds.pl [--replace] [ARTICLE]` | Interactive; `ARTICLE` optionally supplies the date. Automatically runs `rebuild-feeds.pl` when executable, which normally discards the prompted values. Prefer direct regeneration. |
| Perl syntax | `for f in scripts/*.pl; do perl -c "$f" || exit 1; done` | Static analysis only. |
| Shell syntax | `for f in scripts/*.sh; do sh -n "$f" || exit 1; done` | Static analysis only. |
| Perl lint | `perlcritic scripts/*.pl` | Uses `.perlcriticrc`. |
| Shell lint | `shellcheck -s sh scripts/*.sh` | Optional; not a substitute for `sh -n`. |
| HTML links | `htmltest -c .htmltest.yml` | Offline; checks internal links, anchors, images, and metadata. |
| CSS lint | `stylelint styles.css --config .stylelintrc.json` | Uses the checked-in config. |

Do **not** run bare `perl scripts/validate-website.pl`: `--apply` is the
default and rewrites matched HTML, XML, SVG, CSS, JS, and JSON in place. Use
`--check`, or `--noapply` when you explicitly need apply-mode defaults
disabled.

There is no tested "build" phase. Feed and sitemap generation are the
build-like steps, and they modify tracked files.

## Testing and validation policy

- Run `prove t` after changing scripts, tests, article metadata, or generated
  artifacts. Run it from the repository root.
- Regenerate feeds and sitemap before testing. `t/reproducible.t` compares
  committed files byte-for-byte with fresh generator output.
- `t/integrity.t` checks `data/articles.json`, article `<h1>` text, feed links
  and GUIDs, and sitemap coverage. It reads the live working tree.
- `t/reproducible.t` reads the live tree but writes only to a temporary clone.
- `t/links.t` requires `tidy`; without it the file skips rather than fails.
- `t/shell.t` stubs external conversion tools, but requires `sh`, `mktemp`,
  `find`, and `sed`.
- CI does not run the tests or site validators. `.github/workflows/archive.yml`
  only archives, signs, commits, and force-pushes.
- For documentation-only changes, still check YAML, relative paths, commands,
  `git diff --check`, and the final diff. Full site tests are not required
  unless the change touches site sources or generated artifacts.
- Distinguish four levels in reports: static analysis (`perl -c`, `sh -n`,
  linters), generation (rebuild scripts), tests (`prove t`), and real or
  end-to-end checks (`--check-all`, external-link checks, manual browser
  inspection). Do not describe one as another.

## Content and editorial rules

- Classify each statement as a verifiable fact, operational instruction, threat
  model, opinion, historical account, or anonymity/privacy claim. Preserve that
  distinction in edits.
- For security recommendations, record the supported product version, source,
  and date ("as of YYYY-MM-DD"). Prefer primary sources: vendor documentation,
  man pages, standards, release notes, source code, and CVE/NVD records.
- Do not invent commands, features, versions, citations, or test results.
  Qualify unverified claims or mark them as the author's opinion.
- Avoid absolute promises ("100% secure", "impossible to compromise",
  "anonymous") unless the claim is precisely scoped and evidenced. Explain
  assumptions, adversary, and residual risk.
- In controversies, attribute positions and represent evidence fairly; do not
  convert opinion into fact or add false balance.
- Preserve canonical URLs, permanent links, feed GUIDs, copyright notices,
  license text, and author attribution. Do not add unsourced image credits.
- Keep content images fluid: use `max-width: 100%` and `height: auto`, never a
  fixed pixel width. Prefer the existing responsive classes over inline styles.
- Respect the site license in `license.html`. Scripts and `styles.css` are
  separately ISC-like; do not relicense either. Content outside the site
  license needs an explicit `EXCEPTIONS:` notice as described in
  `contribute.html`.
- Keep root-relative feed `<link>` and `<guid>` values. `t/integrity.t` rejects
  absolute feed URLs.

## Safety boundaries

- Never edit or regenerate `archive/cypherpunk-handbook.tar.gz`, `.sha256`,
  `.sig`, or `.pub` by hand. CI creates them; the signature covers the checksum,
  not the tarball.
- Do not edit `.github/workflows/archive.yml` or the LFS rule in
  `.gitattributes` unless explicitly asked. Never run `git filter-repo`,
  force-push, or reproduce the signing step.
- Do not install packages, change system configuration, use credentials, or
  run destructive tests. Do not run `--check-links-external` unless the task
  explicitly requires network access.
- Do not commit, amend, tag, or push unless the user asks.
- Do not revert, reformat, or delete preexisting changes. Start with
  `git status --short` and `git diff`; separate unrelated work from your own and
  report it.

## Skills

Load the matching skill before acting:

| Skill | Use when |
| --- | --- |
| [`security-article-review`](.agents/skills/security-article-review/SKILL.md) | Reviewing or editing security, privacy, or anonymity article content. |
| [`threat-model-and-fact-check`](.agents/skills/threat-model-and-fact-check/SKILL.md) | Verifying claims, sources, versions, or threat models. |
| [`handbook-site-generation`](.agents/skills/handbook-site-generation/SKILL.md) | Adding articles or regenerating feeds, sitemap, and index entries. |
| [`references-and-attribution`](.agents/skills/references-and-attribution/SKILL.md) | Adding citations, links, quotations, images, or license notices. |
| [`content-publishing-validation`](.agents/skills/content-publishing-validation/SKILL.md) | Running the pre-publication checks and reporting results. |

## References

- Contribution rules: `contribute.html`
- License: `license.html`
- Test suite: `t/`
- Validation tool: `scripts/validate-website.pl`
- Archive workflow: `.github/workflows/archive.yml`
