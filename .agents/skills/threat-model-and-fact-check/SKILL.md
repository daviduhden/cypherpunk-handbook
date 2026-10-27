---
name: threat-model-and-fact-check
description: Verify factual, historical, and security claims in the handbook; build explicit threat models; require primary sources, dates, and versions; and distinguish evidence from opinion and anonymity claims.
---

# Threat model and fact check

## When to use

Use this skill when a task requires deciding whether a statement in the
handbook is true, current, or adequately scoped. Typical triggers:

- A sentence contains a number, version, date, standard, CVE, or command.
- A claim uses "secure", "private", "anonymous", "impossible", "always",
  "never", or a comparison between products.
- An article presents a threat model, attack scenario, or security argument.
- A quotation, historical account, or controversial position needs attribution.
- A review comment asks "is this still true?" or "what is the source?".

For prose-level review that does not require source verification, use
`security-article-review`.

## Evidence standard

Use the strongest available source for the claim:

1. Primary technical sources: source code, official documentation, man pages,
   standards, specifications, release notes, advisories, and CVE/NVD records.
2. Authoritative operational sources: vendor security guidance, project
   maintainers' notes, and reproducible test results.
3. Secondary sources: reputable reporting, academic papers, and reference
   works. Use them for context or when primary sources are unavailable, and
   say so.
4. The author's own experience or opinion. Label it as such; it is not
   independent verification.

For each source record: title, publisher or author, URL, publication or
version date, and the date you accessed it. Prefer versioned documentation,
tagged releases, commit permalinks, and stable identifiers over search pages
or unversioned "latest" URLs.

## Procedure

1. **Set the scope.** Read the surrounding section and identify the exact claim
   being checked. Do not verify a paraphrase when the original wording matters.
2. **Write the claim in testable form.** Include the subject, property,
   version, environment, and time boundary. Example: "OpenBSD 7.9 includes
   `doas(1)` in the base system", not "OpenBSD is secure".
3. **Classify it.** Mark the claim as one of:
   - verified fact;
   - supported but time-sensitive;
   - unverified;
   - contested;
   - opinion or prediction;
   - operational instruction.
4. **Find primary evidence.** Open the actual source, not a summary. For a
   command, check the relevant man page and the target release. For a
   vulnerability count, check the query, date range, and data source. For a
   standard, check the clause, not a blog post about it.
5. **Test the boundaries.** Ask what the source does not establish: different
   version, different configuration, different adversary, different threat
   model, or a correlation rather than a cause. Downgrade the claim if the
   evidence only supports a narrower statement.
6. **Build or audit the threat model.** Use the structure below. If the article
   omits a component, add it only where it improves accuracy, not as filler.
7. **Check dates and versions.** Record the product version, source version,
   and "as of" date. Do not present a snapshot as a permanent property. Note
   when a rolling-release project may have changed since testing.
8. **Check neutrality.** For contested topics, identify the parties, their
   claims, and the evidence for each. Attribute quoted positions. Do not
   manufacture balance between a documented fact and an unsupported assertion.
9. **Decide the edit.** Keep, qualify, cite, move to opinion, or remove. Record
   the rationale in the change summary, not as a visible editorial note unless
   the article needs a public caveat.
10. **Recheck dependent artifacts.** A title, date, or filename change can
    affect `data/articles.json`, feeds, sitemap, and tests.

## Threat-model structure

Use these fields, adapting the labels to the article's voice:

- **Asset:** what is being protected (data, identity, availability, integrity).
- **Adversary:** who attacks, with what resources and access.
- **Attack surface:** entry points and trust boundaries.
- **Assumptions:** configuration, user behavior, platform, and network model.
- **Mitigations:** which control addresses which step.
- **Residual risk:** what remains after mitigations, including usability and
  operational failure modes.
- **Out of scope:** threats the article does not address.

An argument that skips the adversary or the residual risk is incomplete, even
if every command is correct.

## Fact-check record

Use a compact table in working notes and summarize it in the final report:

| Claim | Type | Status | Evidence | Action |
| --- | --- | --- | --- | --- |
| Example: default firewall behavior | technical fact | verified | man page, version, date | keep |
| Example: "cannot be compromised" | guarantee | unsupported | no primary source | qualify |
| Example: product comparison | opinion | attributed | author's argument | label |

Statuses must be `verified`, `supported`, `unverified`, `contested`, or
`opinion`. Do not use "probably true" as a status.

## Validation

- Every new normative claim has a source, a version or scope, and a date.
- Every quotation has an attributable source and enough context to be fair.
- Every absolute term has been removed, scoped, or explicitly labeled opinion.
- Commands were checked against the stated product and version; they were not
  executed against production systems.
- The threat model names an adversary and residual risk.
- The final diff does not silently change unrelated claims.
- `git diff --check` passes, and any metadata change is reflected in
  `data/articles.json` and regenerated artifacts.

## Common problems

- **Treating a vendor claim as independent evidence.** A project's own security
  page is primary for what the project claims, not proof that the claim holds.
- **Counting CVEs without defining the query.** Totals depend on date range,
  product mapping, and deduplication. State the method and date.
- **Using "latest" as a version.** It changes. Pin the version or date.
- **Confusing absence of evidence with evidence of absence.** A missing CVE is
  not proof of safety.
- **Confusing privacy with anonymity.** Encryption, no logging, and Tor are
  different properties with different failure modes.
- **Quoting without context.** A mailing-list excerpt can misrepresent the
  thread; link the message and identify the speaker.
- **Dead or redirected sources.** Prefer permanent links and note when the
  original is gone.

## References

- `AGENTS.md` — repository rules and source hierarchy.
- `contribute.html` — evidence, style, and sourcing requirements.
- `articles/c-language.html` — example of a dated, method-stated CVE analysis.
- `articles/openbsd.html` — examples of explicit threat-model paragraphs and
  claims that need scope.
- `articles/openbsd-hardening.html` — version-sensitive operational guidance.
- `articles/searxng-on-openbsd.html` — rolling-release caveat and tested
  version statement.
- `articles/security-terms.html` — definitions useful for precise claims.
- `t/integrity.t` — metadata consistency checks after edits.

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
