# Contributing

Thank you for helping improve Cypherpunk Handbook. Contributions should make the site more accurate, readable, accessible, and maintainable while preserving its static, mirror-friendly design.

## Issues and pull requests

- Search existing issues before opening a new one. Describe the affected page or script, the observed problem, and a concise reproduction when relevant.
- For substantial changes, open an issue first to discuss scope. Small corrections can be proposed directly in a pull request.
- Keep each pull request focused. Explain what changed, why it is needed, and which checks you ran. Link related issues when applicable.
- Do not include secrets, private personal data, generated archive artifacts, or unrelated formatting changes.

## AI-assisted contributions

The use of artificial intelligence (AI) tools is explicitly permitted. Contributors are not required to disclose AI assistance. Contributors remain responsible for reviewing AI-assisted changes, verifying factual claims and sources, and ensuring that contributions follow the project's standards and license.

## HTML and content

- Follow the existing semantic HTML, heading hierarchy, language metadata, and relative-link conventions.
- Keep article content in `articles/`; update the matching metadata in `data/articles.json` when adding or changing an article.
- Preserve useful alternative text, descriptive link text, table headers, and keyboard-operable controls.
- Keep authored page content separate from maintenance templates and generated feeds. Regenerate derived feeds and the sitemap only through their existing scripts when those outputs need to change.

## CSS

- Make changes in the shared `styles.css` unless an existing component convention provides a better location.
- Reuse the defined custom properties and established responsive patterns. Preserve readable line lengths, visible focus, forced-colors behavior, and reduced-motion preferences.
- Avoid unnecessary specificity, duplicated overrides, fixed-width content, and rules that unintentionally change unrelated pages.
- Check both narrow and wide layouts and verify that focus indicators remain visible.

## Scripts and configuration

- Preserve the existing Perl and POSIX shell interfaces and use the interpreter declared by each script's shebang.
- Keep generated archive and feed behavior reproducible. Do not add dependencies without a clear need and documented support.
- Do not change GitHub Actions triggers, deployment behavior, or archive signing as part of an unrelated content contribution.

## Checks before submitting

Run the relevant existing checks from `AGENTS.md`; the complete Perl suite is `prove -lr t`. If a check cannot be run, state why. Review the final diff for unintended changes, verify local links and assets, and inspect the rendered page at desktop and mobile widths when feasible.

## Repository-only documentation

Root-level GitHub documents, agent instructions, `docs/`, test files, and development configuration are for maintainers. Do not add them to public page content or generated feed entries. The archive workflow and server synchronization explicitly filter these known repository paths while keeping the source files versioned in GitHub. Do not exclude all Markdown files: some projects may use Markdown as public content.
