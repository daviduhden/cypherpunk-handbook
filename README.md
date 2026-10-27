# Cypherpunk Handbook

Cypherpunk Handbook is a static, hand-authored website about privacy, security, open technologies, and related topics. Its pages are served as files; the repository has no package manifest, local build command, or site framework.

## Repository layout

- `index.html`, `contact.html`, `contribute.html`, `manifesto.html`, and `license.html` are the main pages.
- `articles/` contains the long-form handbook articles.
- `styles.css` is the shared site stylesheet; `images/` contains local visual assets.
- `data/articles.json` supplies article metadata to maintenance scripts, and `templates/articles.html` is a reference template.
- `feeds/` and `sitemap.xml` contain generated public discovery files.
- `scripts/` contains Perl and shell maintenance utilities; `t/` contains their test suite.
- `archive/` contains signed release artifacts maintained by the archive workflow.
- `.github/`, root Markdown documentation, `AGENTS.md`, `docs/`, and development configuration are repository-only material and are omitted from site archives and server synchronization.

## Technologies and requirements

The site uses semantic HTML, CSS, and local images. Perl scripts use Perl core modules. The repository does not require dependency installation to view the site: open `index.html` in a browser or serve the repository directory with a static web server. Maintenance checks use the tools listed in `AGENTS.md` and the script-specific requirements documented in `scripts/`.

## Updating content

Add or edit an article page in `articles/`, follow the existing HTML and metadata conventions, update `data/articles.json`, and regenerate the public feeds and sitemap with the corresponding scripts. The article metadata file and the page content are separate inputs used by the maintenance tools; keep their slugs and publication details consistent. Review links, language, headings, image alternatives, and keyboard focus behavior before proposing the change.

## Styles and navigation

Main pages load the root `styles.css`. Navigation and article contents are authored in HTML. Preserve relative links so the same files work on the site's supported mirrors. The stylesheet supplies shared layout, typography, responsive rules, and focus and motion preferences.

## Validation

Run the existing Perl test suite with `prove -lr t` from the repository root. The repository's `AGENTS.md` lists additional read-only syntax, link, HTML, and style checks. Do not run archive signing or publishing workflows as a local validation step.

## Archiving and deployment

The scheduled or manually dispatched GitHub Actions archive workflow creates a source tarball, checksum, and signature. It is an archival process, not a site build or deployment. It excludes repository documentation, VCS metadata, agent instructions, development tooling, tests, caches, archive output, and temporary archive files. The separate [`scripts` repository](https://github.com/daviduhden/scripts/blob/main/openbsd/sync-website.ksh) contains the OpenBSD synchronization script used for server updates; its repository settings and operational steps are documented there. Do not copy a Git checkout or its `.git` directory into a public document root.

## License

See `license.html` for the website and content terms. Script and stylesheet notices may define separate terms; review the notice in each file before reusing it.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a change. Please use GitHub issues and pull requests for public project discussion. Report sensitive conduct concerns privately to the contact address published on [contact.html](contact.html).
