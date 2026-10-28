# Learning path: from UI to shipped API

Use Wayfarer as a small laboratory. Read the code, change one behavior, and run the gates after each change.

## Stage 1 — Core coding
Learn TypeScript types, pure functions, React state, events, and derived data. Trace `Home` from state declarations to rendered controls, then follow a task click into `update()` and the localStorage effect. Practice by adding a filter without changing the data model.

## Stage 2 — Browser data flow
A click creates an event, React updates state, React renders again, and the persistence effect serializes the new state. The initial `ready` guard prevents the seed render from overwriting stored data. `safeLoad` treats storage as untrusted input. This is useful even before an API exists.

## Stage 3 — HTTP and API boundaries
An HTTP request has method, URL, headers, and optional body. A server routes it, authenticates the caller, validates the body, runs domain logic, and returns status, headers, and JSON. REST is a convention for resource boundaries: `GET /tasks`, `POST /tasks`, `PATCH /tasks/:id`, `DELETE /tasks/:id`. Keep UI concerns out of the domain layer and keep database details out of HTTP handlers.

Wayfarer deliberately has no API or authentication yet: one user, one browser, no server requirement. Adding an API before the product needs synchronization would add deployment, auth, validation, and failure modes without business value. Read [`api-security.md`](./api-security.md) for the future design and the session/cookie/token threat model; do not describe those future controls as features the MVP already has.

## Stage 4 — Identity and authorization lesson
Before implementing a second device or account, be able to explain the difference between authentication (“who are you?”), authorization (“may you access this project?”), a server session, a cookie, and a bearer token. Trace where a password travels during login, where a session cookie travels afterward, and why a valid identity still cannot access another user's task.

Practice the attacks in the companion lesson: session fixation, session theft/replay, XSS cookie or token theft, CSRF, insecure storage, expiry/rotation/revocation, refresh-token reuse, logout, and IDOR. For each, write the attack precondition, the observable failure, and at least one mitigation plus a regression test.

## Stage 5 — Safe future slice
When a second device or account is required, implement one vertical slice: `GET /api/health`, then login/session establishment, then `GET /api/tasks`, then `POST /api/tasks`. Define schemas before handlers, return `201` for creation, `200` for reads, `400` for malformed input, `401` for missing/invalid identity, `403` for authenticated-but-forbidden access, `404` for absent resources, `409` for conflicts, and `500` only for unexpected server failures. Add integration tests for ownership, cookie attributes, expiry, logout, CSRF, and revocation before switching the UI from localStorage.

Use an expand/contract rollout: dual-read or dual-write only while migrating, then remove local-only paths after a verified cutover. Keep localStorage as an offline fallback until the server path is proven.

## Stage 6 — Shipping and operations
Feature branch → PR → Jenkins gates → merge to `main` → build an immutable commit-SHA image → stage → smoke test → promote or roll back the same image. Learn failures by reading logs, reproducing locally, and changing one variable at a time. Redact passwords, cookies, session IDs, refresh tokens, and authorization headers from every diagnostic path.
