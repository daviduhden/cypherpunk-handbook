---
name: security-article-review
description: Review or revise security, privacy, and anonymity articles in articles/ for claim accuracy, threat-model clarity, safe operational guidance, neutrality, and preserved attribution.
---

# Security article review

## When to use

Use this skill when a task touches the substance of an article in
`articles/*.html`, including:

- Reviewing a draft or an existing security, privacy, or anonymity article.
- Correcting technical claims, commands, defaults, or version references.
- Adding warnings, preconditions, or threat-model context.
- Assessing whether a statement is fact, guidance, opinion, history, or an
  anonymity claim.
- Responding to a review comment about accuracy, safety, or neutrality.

Do not use it for pure markup or CSS work, and do not use it for feed or
sitemap generation. Use `handbook-site-generation` for generated artifacts and
`content-publishing-validation` for publication checks.

## Inputs and boundaries

- Read `AGENTS.md`, `contribute.html`, and `license.html` first.
- Identify the target file and the requested scope. Do not rewrite unrelated
  sections or "improve" the author's voice without a request.
- Article HTML is the source. Never convert it to Markdown or move it into a
  template.
- Preserve the author's pseudonym or name, byline, canonical URL, copyright,
  and license notices.

## Procedure

1. **Establish the baseline.** Run `git status --short` and inspect the target
   article's diff. Record preexisting changes so you do not revert them. Read
   the article header, TOC, and conclusion before editing.
2. **Classify the content.** For each section, decide whether it is:
   - verifiable technical fact;
   - operational guidance;
   - a threat model or security argument;
   - an opinion or prediction;
   - historical or archival information;
   - a privacy or anonymity claim.
   Label opinion and prediction explicitly when the text blurs the line.
3. **Inventory claims.** List normative claims, commands, version numbers,
   defaults, guarantees, superlatives, and quoted material. Mark each as
   verified, unverified, contested, or opinion. Use
   `threat-model-and-fact-check` for claims that need source-level work.
4. **Check the threat model.** A security argument should state, at least
   implicitly, the asset, adversary, capabilities, attack surface, assumptions,
   mitigation, and residual risk. If an article promises a property without
   those boundaries, narrow the claim or add the missing conditions.
5. **Check operational guidance.** Confirm that commands match the stated
   product and version, that privileged steps are identified, and that
   destructive or lockout-prone actions have warnings, backups, or rollback
   notes. Do not invent commands or test them against production systems.
6. **Check privacy and anonymity claims.** Separate transport anonymity (for
   example Tor or I2P), endpoint security, metadata leakage, correlation, and
   logging. Do not treat one as a guarantee of another. Prefer scoped language
   over absolute promises.
7. **Check neutrality and attribution.** Attribute quotes and controversial
   positions. Represent the strongest opposing argument fairly. Keep criticism
   evidence-based and avoid promotional language. Do not add false balance.
8. **Edit minimally.** Preserve heading IDs, TOC links, code blocks, tables,
   blockquotes, and inline links unless the change requires them. Keep U.S.
   English spelling and the existing 80-column HTML style.
9. **Recheck the article as a whole.** Verify that the lede, TL;DR, body, and
   conclusion no longer contradict each other after the edit.

## Review checklist

- [ ] The article's type and scope are clear.
- [ ] Every new or changed factual claim has a primary source or is qualified.
- [ ] Versions, dates, and "as of" statements match the evidence.
- [ ] Commands include the correct user, shell, path, and target version.
- [ ] Risky steps warn about lockout, data loss, or reduced security.
- [ ] Threat-model assumptions and residual risk are visible.
- [ ] Anonymity, privacy, and security are not conflated.
- [ ] Opinion is labeled and not presented as verified fact.
- [ ] Quotations are attributed; controversial claims are represented fairly.
- [ ] Canonical URL, byline, copyright, and license text are intact.
- [ ] No personal data, credentials, or unsupported image credits were added.

## Validation

- Re-read the changed passages against their cited sources.
- Confirm that `data/articles.json` still matches any changed title or filename;
  `t/integrity.t` compares `title_en`/`title_es` with the page `<h1>`.
- If metadata, an article title, or the publication date changed, regenerate
  feeds and run the relevant tests as described in
  `content-publishing-validation`.
- Run `git diff --check` and inspect the final diff for accidental markup
  changes.
- Report separately what was verified, what remains an author's opinion, and
  what could not be checked.

## Common problems

- **Absolute guarantees.** Phrases such as "impossible", "100% secure", or
  "anonymous" usually hide unstated assumptions. Scope them or mark them as
  opinion.
- **Version drift.** A command copied from an older release may no longer
  apply. Record the tested version or add a dated caveat.
- **Missing adversary.** "Secure" is meaningless without an attacker model and
  a boundary.
- **Conflating privacy with anonymity.** A privacy tool can still leak
  identity through metadata or correlation.
- **Unsourced quotations.** A blockquote without a source or date is not
  evidence.
- **Over-editing.** Replacing the author's argument with a generic summary
  destroys the document's value and voice.
- **Broken anchors.** Renaming a heading without updating the TOC or inbound
  links breaks navigation.

## References

- `AGENTS.md` — repository architecture, commands, and editorial policy.
- `contribute.html` — content guidelines, article structure, licensing, and
  metadata rules.
- `license.html` — site terms and separately licensed files.
- `articles/openbsd.html` — examples of explicit threat-model paragraphs.
- `articles/openbsd-hardening.html` — operational guide with warnings.
- `articles/searxng-on-openbsd.html` — version-scoped operational guide.
- `articles/qubes-os.html` and `articles/why-i-stopped-using-linux.html` —
  examples of opinion and controversy that must remain attributed.
- `t/integrity.t` — metadata and cross-artifact consistency checks.

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
