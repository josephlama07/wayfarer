# Changelog policy

Wayfarer uses a **human-written changelog with automated validation**. Automation checks the policy; it does not generate entries, calculate versions, create Git tags, or rewrite `CHANGELOG.md`.

## Required format

`CHANGELOG.md` must contain:

```markdown
# Changelog

## Unreleased

- Describe the unreleased change.

## [1.0.0] - YYYY-MM-DD

- Describe the released change.
```

`package.json.version` is the application version source of truth. Release validation requires a matching tag (`v1.0.0`) and a matching release heading.

## Changes that require an entry

Add a bullet under `## Unreleased` for changes that affect:

- application behavior or user-visible functionality;
- APIs, data formats, persistence, or migrations;
- security, privacy, authentication, or authorization;
- performance, reliability, or operational behavior;
- runtime dependencies or deployment behavior.

Write entries for users or operators, not implementation-only commit details.

## Changes that may omit an entry

These categories may omit a changelog entry when they have no user or operator impact:

- documentation-only changes;
- CI or Jenkins-only changes;
- formatting-only changes;
- development-only tooling or test changes.

The pull request description must state the applicable exception using exactly one machine-readable marker:

```text
Changelog-Exception: documentation
```

Allowed values are `documentation`, `ci`, and `tooling`. The exception does not bypass version or release-tag validation, and it cannot be used when the pull request also changes application/runtime files.

## Enforcement boundary

- `npm run check:metadata` validates required files, the application version, and `## Unreleased`.
- `npm run check:release` additionally validates the release tag and release heading.
- Pull-request changed-file enforcement is a later phase and will determine whether `CHANGELOG.md` was actually modified.
- Changelog generation and commit-message-based versioning are out of scope.
