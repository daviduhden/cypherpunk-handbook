---
name: content-publishing-validation
description: Run and report the handbook's static checks, generation steps, Perl regression tests, and broad local validation without letting the default apply mode rewrite tracked files.
---

# Content publishing validation

## When to use

Use this skill before declaring a content, markup, script, or metadata change
finished, and whenever a task asks for tests, lint results, link checks, or a
publication-ready diff. It applies to:

- article and metadata changes;
- generated feed or sitemap changes;
- script or test changes;
- documentation-only changes that still need path, YAML, and link checks.

## Validation levels

Do not collapse these into a single claim such as "all tests pass".

| Level | What it establishes | Examples |
| --- | --- | --- |
| Static analysis | Syntax and style only | `perl -c`, `sh -n`, `perlcritic`, `stylelint`, `shellcheck`, `xmllint --noout`, `tidy -errors` |
| Generation | Derived files match their sources | `rebuild-feeds.pl`, `rebuild-sitemap.pl` |
| Tests | Isolated behavioral and consistency checks | `prove t` |
| Real or broad check | Multiple checks plus generated output inspection | `validate-website.pl --check-all`, external-link checks with approval, manual browser review |

There is no build system. Generation rewrites tracked artifacts and is not a
validation by itself.

## Procedure

1. **Capture the baseline.** Run `git status --short` and `git diff --stat`.
   Identify preexisting changes and do not revert or reformat them.
2. **Classify the change.** Decide whether it is documentation only, article
   content, metadata, generated artifact, script, or test. This determines the
   minimum checks.
3. **Check source consistency before generating.**
   - Article title and filename agree with `data/articles.json`.
   - Publication `pubdate` is separate from the article `<time>` update value.
   - Index links point to existing files.
   - Canonical URLs and root-relative feed identifiers are intact.
   - New citations and media have real sources and licenses.
4. **Regenerate when required.** Run `perl scripts/rebuild-feeds.pl` and
   `perl scripts/rebuild-sitemap.pl` after article, title, date, or public-page
   changes. Inspect `git diff -- feeds sitemap.xml` before testing.
5. **Run static checks.**
   ```sh
   for f in scripts/*.pl; do perl -c "$f" || exit 1; done
   for f in scripts/*.sh; do sh -n "$f" || exit 1; done
   ```
   When installed, also run `perlcritic scripts/*.pl`,
   `shellcheck -s sh scripts/*.sh`, and
   `stylelint styles.css --config .stylelintrc.json`.
6. **Run the regression suite.** From the repository root:
   ```sh
   prove t
   ```
   This is offline and uses temporary fixtures for mutating scripts.
   `t/integrity.t` and `t/reproducible.t` read the live tree; run them on a
   consistent checkout, not while another edit is in progress.
7. **Run the broad local gate when the tools exist.**
   ```sh
   perl scripts/validate-website.pl --check-all
   ```
   It implies `--check` and internal link checking, runs `prove`, and invokes
   optional linters that are installed. It requires `tidy`, `xmllint`,
   `dprint`, and `jq` for the file types present. Missing optional tools are
   skipped; missing required tools exit `1` before tests run.
8. **Inspect the report, not only the exit code.** Read the summary for skipped
   checks, formatting differences, broken links, and linter output. Exit `0`
   does not mean every optional tool ran.
9. **Review the final diff.** Run `git diff --check`, inspect changed files,
   and confirm that no generated file is stale and no unrelated file was
   normalized.
10. **Report by level.** State the exact commands, results, skips, and any
    check you could not run. Do not say "validated" without naming what ran.

## Documentation-only checks

For `AGENTS.md` and `.agents/skills/**`, the site tests do not validate the
documentation. Instead:

- Parse each `SKILL.md` front matter with a local YAML parser; do not install
  one.
- Confirm `name` matches the directory name and `description` is present.
- Verify every relative path, skill link, and referenced command exists.
- Check for duplicate or contradictory instructions across `AGENTS.md` and the
  skills.
- Run `git diff --check` and `git status --short`.
- Do not claim that `prove t` or `--check-all` tested Markdown or YAML; neither
  tool reads those files.

## Command behavior and pitfalls

### `scripts/validate-website.pl`

- Bare invocation defaults to `--apply` and rewrites matched HTML, XML, SVG,
  CSS, JS, and JSON in place. Never use it as a read-only check.
- `--check` does not write target files, but it may create temporary reports
  and a temporary dprint config.
- `--noapply` disables the default apply mode; `--check` remains the preferred
  read-only invocation because it also reports formatting differences.
- `--check-all` enables check mode and internal links, but not spelling or
  external-link checking.
- `--check-links` alone is offline. `--check-links-external` implies
  `--check-links` and additionally contacts remote URLs with `curl`.
- A proposed link fix is not a pass: in check mode the broken link still fails
  until the fix is applied. Read the link report for the proposed target.
- The link checker ignores unquoted attributes, `srcset`, `action`, `poster`,
  inline CSS `url()`, `@import`, and JavaScript-generated URLs.
- File collection prunes `.git`, `node_modules`, `dist`, `build`, `.cache`, and
  `tmp`.
- `--check-spelling` supports only `en_US`; pages with other `lang` values
  fail. Do not enable it casually.
- dprint may resolve or download npm plugins while setting up its temporary
  config. Do not describe a `--check` run as fully offline; a plugin download
  failure is downgraded to a skip in check mode.
- The default apply mode does not exclude `templates/` or `archive/`. This is
  another reason to use `--check`.

### `prove t`

- `t/links.t` skips entirely if `tidy` is unavailable.
- `t/shell.t` needs `sh`, `mktemp`, `find`, and `sed`; it stubs `pandoc`,
  `espeak-ng`, `ffmpeg`, and `rsvg-convert`.
- `t/reproducible.t` fails if committed feeds or `sitemap.xml` differ from
  fresh generator output, or if generator output is nondeterministic.
- An article without `<time datetime>` falls back to file mtime and can make
  reproducibility fail across clones.
- Tests do not modify tracked files. The site tests and site validator are not
  run in CI. The separate `agent-knowledge-validation.yml` workflow runs only
  the shared contract tests and the read-only pull request range gate.

### CI and archives

`.github/workflows/archive.yml` runs daily and on manual dispatch. It builds
and signs the archive, rewrites history with `git filter-repo`, and
force-pushes `main`. It does not run site tests or linters. The separate
`.github/workflows/agent-knowledge-validation.yml` workflow is read-only and
validates only the shared agent-knowledge contract. Never invoke the archive
workflow's destructive steps locally.

The source tar excludes GitHub and maintainer Markdown, VCS metadata, agent
instructions, development configuration, tests, caches, and known editor
backups while retaining public site files. Keep the same internal-path policy
in the OpenBSD server sync; exclude only verified repository-only paths rather
than all Markdown or hidden files.

## Minimum matrix

| Change | Required checks |
| --- | --- |
| Article prose only | `git diff --check`; source spot-check; `prove t` if metadata or links changed |
| Article title, date, filename, or metadata | Update `data/articles.json`; regenerate feeds and sitemap; `prove t` |
| New article | JSON, index, feeds, sitemap; `prove t`; `--check-all` when possible |
| `styles.css` or HTML structure | `stylelint`; `prove t`; `--check-all` when possible; inspect responsive and focus behavior in a browser when available |
| Perl script | `perl -c`; `perlcritic`; `prove t` |
| Shell script | `sh -n`; `shellcheck`; `prove t` |
| `AGENTS.md` or skills | YAML parse, path/link checks, `git diff --check`; no site-test claim |

## Common problems

- **Running the validator without `--check`.** It formats source and generated
  files in place.
- **Assuming `--check-all` is exhaustive.** It omits spelling and external
  links, and optional linters may be absent.
- **Ignoring skips.** `prove` or `tidy` may be missing; the suite can pass with
  less coverage than expected.
- **Testing before regenerating.** This guarantees reproducibility failures or
  hides stale output.
- **Editing generated files by hand.** Regeneration will overwrite them.
- **Treating a green link checker as factual verification.** Link reachability
  is not source support.
- **Using network checks on onion or I2P URLs.** They are not clearnet
  reachable and are intentionally excluded from offline checks.
- **Forgetting `git diff --check`.** Formatting tools and manual edits can
  introduce trailing whitespace.

## Report template

```text
Static analysis: <commands and results>
Generation: <commands and resulting diff>
Tests: <prove output summary and skips>
Broad check: <--check-all result, tools missing, link report>
Unverified: <checks not run and why>
Final diff: <files changed; git diff --check result>
```

## References

- `AGENTS.md` — command table and repository safety rules.
- `scripts/validate-website.pl` — modes, dependencies, and exit codes.
- `t/00-syntax.t` — Perl and shell syntax checks.
- `t/integrity.t` — metadata, feed, and sitemap consistency.
- `t/reproducible.t` — byte-for-byte generator comparison.
- `t/links.t` — internal link-checker regression tests.
- `.htmltest.yml`, `.perlcriticrc`, `.stylelintrc.json`, `dprint.json` —
  checker configuration.
- `.github/workflows/archive.yml` — CI behavior; do not modify for validation.

## Maintenance & Continuous Learning

Whenever this skill is used to change the repository, review this skill after
the implementation. Correct procedures that proved wrong, update commands,
paths, configuration and examples, incorporate reusable findings, and remove
outdated assumptions. Review the applicable root and nested `AGENTS.md` files,
specialized agents and related skills; update only the knowledge affected by
the work. Validate local references and run
`python3 scripts/validate-agent-knowledge.py --scope worktree` plus the
applicable project checks. For pull request comparisons, use the documented
`--scope range --base BASE_REF --head HEAD_REF` command. The canonical validator
is read-only and is required even when a task restricts execution of project
scripts; this does not authorize running installers or changing the host.
Report checks actually performed. A structural pass does not prove semantic
relevance, and a task is incomplete until synchronization is validated.
