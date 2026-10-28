# API and security foundations

This is an educational guide, not a claim that the MVP already has an API or authentication. **Wayfarer's current MVP is localStorage-only: one browser, no account, no server, no login, no session, and no tokens.** The designs below describe a future API-backed Wayfarer and the security reasoning to learn before adding one.

## Request lifecycle: the future Wayfarer path

A current browser event can update local state without leaving the machine. In a future API flow, a request would follow this sequence:

1. The user submits the login form over HTTPS.
2. The browser sends the request to the API with the form body; the password is sent only over the encrypted TLS connection and should never be logged.
3. The server rate-limits the attempt, validates the input, looks up the user, and compares the password with a slow password hash (never plaintext or reversible encryption).
4. On success, the server creates a fresh unpredictable session identifier and sends it in a `Set-Cookie` response header.
5. The browser stores the cookie according to its attributes and automatically includes it on eligible future requests.
6. DNS/TLS and a reverse proxy route a request such as `GET /api/projects/123/tasks` to the application.
7. The application authenticates the cookie/session, then authorizes the requested project: authentication answers “who are you?”; authorization answers “may you access this resource?”
8. The server validates types, lengths, enums, dates, and ownership; domain logic reads or changes state; the response returns JSON and a status code.
9. The client updates its cache and UI. Log correlation IDs across the boundary, never passwords, session IDs, cookies, or bearer tokens.

A successful login does **not** grant permanent access to every URL. Every protected request repeats authentication and authorization checks.

## Sessions, cookies, and tokens are different things

- **Session:** server-side state representing a logged-in browser. It commonly stores `session_id → user_id, issued_at, expiry, revoked_at`, while the browser holds only an opaque identifier.
- **Cookie:** a browser storage and transport mechanism. A cookie may contain a session ID, a CSRF token, or other data; “cookie” does not automatically mean “secure.”
- **Token:** a credential presented to prove access. An opaque access token is looked up server-side; a signed JWT carries claims that the server verifies. A signed token is not secret: anyone holding it can usually read its non-encrypted claims.

For a browser-based Wayfarer, a server-side session in a hardened cookie is a straightforward default. It allows server-side revocation and avoids putting bearer credentials in JavaScript-readable storage. A bearer-token design can be appropriate for native clients or service-to-service calls, but it needs an explicit storage, expiry, refresh, and revocation plan.

### Cookie session versus bearer token

**Cookie session (often the safer browser default):**

```http
HTTP/1.1 200 OK
Set-Cookie: __Host-wayfarer_session=opaque-random-id; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=1800
```

The browser sends the cookie automatically to the matching origin. JavaScript cannot read an `HttpOnly` cookie, but an XSS bug can still make requests as the user unless the XSS is prevented and other defenses limit impact.

**Authorization-header token:**

```http
GET /api/tasks HTTP/1.1
Authorization: Bearer opaque-access-token
```

The client must attach the token itself. Do not place long-lived bearer tokens in `localStorage` or `sessionStorage` merely because they are convenient: injected JavaScript can read them and exfiltrate them. If a token must be used in a browser, use short-lived access tokens, keep refresh credentials out of JavaScript where possible, and design rotation and revocation deliberately.

## Cookie controls

For a session cookie, set:

- `Secure`: send only over HTTPS. Do not weaken this in production.
- `HttpOnly`: block `document.cookie` reads. This reduces cookie theft through XSS; it does not make XSS harmless.
- `SameSite=Lax` or `Strict`: limit cross-site sending and reduce CSRF. Choose `None` only when cross-site use is required, and then require `Secure`.
- `Path=/`: make the scope explicit. Prefer the `__Host-` prefix when possible: no `Domain`, `Path=/`, and `Secure`.
- A bounded lifetime (`Max-Age` or `Expires`): idle and absolute timeouts should be enforced server-side too.

Do not treat cookie attributes as authorization. The server must still validate the session and check ownership on every request.

## Login, logout, expiry, and rotation

Passwords should be collected only over HTTPS, checked against a modern password hash, and protected by rate limits and monitoring. Never put passwords in URLs, analytics, logs, error messages, or client-side storage.

At login, issue a **new** session ID after the password succeeds. This prevents session fixation: an attacker who caused a victim to use a known pre-login session ID must not have that ID become authenticated. Rotate the session ID after privilege changes as well.

Use both idle and absolute expiration. For token designs, keep access tokens short-lived and rotate refresh tokens on use: invalidate the old refresh token and detect reuse. Store refresh-token hashes or opaque references server-side so a stolen refresh token can be revoked. JWT expiry alone is not immediate revocation; maintain a denylist, token-version check, or server-side session record when early invalidation matters.

Logout should be a server action, not only a UI redirect: revoke/delete the server session or refresh-token family, then return a cookie-clearing response with matching `Path`/`Domain` attributes. The client should clear cached private data. If a stolen access token remains valid until expiry, logout cannot magically retract it unless the server checks revocation.

## Session theft and common attack scenarios

### Session hijacking/theft
An attacker obtains a valid session ID or bearer token through malware, a leaked log, an unsafe proxy, browser sync, or a compromised device. They replay it from another machine; the server sees a valid credential and may accept the request.

**Mitigations:** HTTPS everywhere, `Secure` cookies, redacted logs, short lifetimes, rotation after login and privilege changes, server-side revocation, refresh-token reuse detection, careful device/session management, and re-authentication for sensitive actions.

### XSS cookie/token theft
A task title is rendered as HTML without escaping. An injected script reads `document.cookie` (if the cookie lacks `HttpOnly`) or reads a token from `localStorage`, then sends it to the attacker. `HttpOnly` blocks direct cookie reads, but the script can still issue same-origin requests as the victim.

**Bad:** `localStorage.setItem('accessToken', token)` plus unsafe HTML rendering.

**Better:** escape task content, use framework-safe rendering, add a restrictive Content Security Policy, keep browser sessions in `HttpOnly` cookies, validate all input, and avoid dangerous DOM sinks.

### CSRF
A victim is logged in with a cookie. They visit an attacker page that submits a cross-site `POST /api/tasks/delete`. The browser may attach the cookie automatically.

**Mitigations:** `SameSite=Lax`/`Strict`, verify the `Origin` header where appropriate, and use a CSRF token for state-changing cookie-authenticated requests. Require a non-simple header such as `X-CSRF-Token` when the architecture supports it. CORS is not a CSRF defense by itself.

### Insecure storage and replay
A token is copied into a Git commit, browser storage, a crash dump, a URL, or an unredacted log. Anyone who gets it replays it until expiry or revocation.

**Mitigations:** never put secrets in URLs or source control; redact headers and cookies; use short-lived credentials; rotate/revoke; bind sensitive actions to fresh authentication; and keep secrets in a server-side secret manager.

### IDOR / broken ownership authorization
The attacker changes `/api/projects/123/tasks` to `/api/projects/124/tasks`. The session is valid, but the handler checks only that the user is logged in—not that project 124 belongs to that user.

**Bad:** `SELECT * FROM tasks WHERE project_id = :id`.

**Better:** scope the query and mutation to the authenticated owner in one operation, for example `WHERE project_id = :id AND owner_id = :user_id`, and test both owned and unowned IDs. Never use a URL ID as proof of ownership.

## Boundaries, validation, and transport controls

Use resource-oriented endpoints and small handlers. Validate at the boundary with allowlists: title length, known status (`Todo`, `In Progress`, `Done`), known priority, valid ISO date, and an existing project ID. Reject unknown or oversized fields. TypeScript types disappear at runtime; requests can be hand-written.

Return consistent errors such as `{ "error": { "code": "VALIDATION_ERROR", "message": "...", "fields": {} } }`. Do not leak stack traces, SQL, file paths, account existence, or secrets. Use HTTPS, narrow CORS to the known frontend origin, and never use `Access-Control-Allow-Origin: *` with credentials. Add rate limits to login and write endpoints; cap body sizes and pagination; use parameterized queries; keep dependencies and base images patched.

## Secrets, images, and logs

Secrets belong in a runtime secret manager or Jenkins credentials, never Git, Dockerfile layers, committed `.env` files, or client bundles. Scan dependencies, pin and regularly rebuild base images, run containers as non-root, and scan images before publishing.

Logs may include timestamp, level, route, status, duration, and correlation ID. Redact `Authorization`, cookies, session IDs, refresh tokens, passwords, email addresses, sensitive task content, and database URLs. Never log full request bodies by default.

## Testing strategy

Unit-test validation, session expiry, CSRF checks, and domain rules. Integration-test login, logout, rotation, revocation, refresh-token reuse, and ownership boundaries against a disposable database. Contract-test status codes and error shapes. Browser-test that private data is cleared on logout and that a second user cannot access the first user's project. Security-test malformed JSON, oversized payloads, injection strings, XSS payloads, CORS behavior, cookie attributes, replay after expiry/revocation, and rate limits. Keep a regression test for every discovered bug.

## Learning exercise/checklist

Use this as a future, server-backed Wayfarer design exercise; do not add login to the current localStorage-only MVP just to complete it.

- [ ] Draw the request sequence from login through `GET /api/tasks` and label where credentials, cookies, and tokens travel.
- [ ] Choose cookie session or bearer tokens and write down the browser storage, expiry, rotation, revocation, and logout plan.
- [ ] Define cookie attributes and explain why `HttpOnly` reduces theft but does not stop XSS actions.
- [ ] Threat-model session fixation, session hijacking, XSS, CSRF, insecure storage, replay, and IDOR.
- [ ] Write one bad and one good ownership query for `GET/PATCH/DELETE /api/tasks/:id`.
- [ ] Add tests for missing identity (`401`), authenticated-but-forbidden access (`403`), missing resources (`404`), expired credentials, revoked credentials, CSRF failure, and cross-user access.
- [ ] Verify with browser devtools that passwords are sent only over HTTPS, cookies have the intended attributes, tokens never appear in URLs/logs, and logout invalidates the server-side credential.

## Bad patterns in this project

- Reading `JSON.parse(localStorage)` without a try/catch lets corrupted state crash the UI.
- Saving seed state before hydration loses the user's data.
- Hard-coded task ID `1` makes focus actions target the wrong task.
- Hard-coded metrics lie after updates.
- A “search” button that does nothing teaches a false affordance.
- Adding PostgreSQL merely because production apps use it increases operational risk without solving an MVP need.
- Publishing `latest` makes rollback ambiguous; commit-SHA tags make the exact artifact recoverable.
