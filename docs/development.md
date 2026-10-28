# Development

The app is Next.js 14 with TypeScript. Keep changes inside the three MVP outcomes. Use feature branches (`feature/task-filters`), run `npm ci`, then `npm run lint`, `npm run typecheck`, and `npm run build` before opening a PR. Browser state is validated defensively: malformed `wayfarer:v2` JSON falls back to seed data, and writes wait until the initial load completes.

The app has no auth, API, hosted database, or collaboration model. Reset local data from the sidebar when testing persistence. Docker is optional for daily development; `docker compose up --build` exercises the production runtime.
