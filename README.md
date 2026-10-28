# Wayfarer MVP

Wayfarer is a local-first tourism trip planner. It ships three focused areas: trip management, day-by-day itineraries, and saved ideas that can become stops. Data stays in versioned browser localStorage; there is no backend, external travel API, maps, bookings, payments, or real authentication in this MVP.

## Run locally
```bash
npm ci
npm run dev
# quality gates
npm run lint && npm run typecheck && npm run build
```
Use `docker compose up --build` for the production-shaped container. `docker compose --profile db up` also starts the educational PostgreSQL service; the app does not connect to it yet.

Feature branches feed pull requests. Jenkins runs install, lint, typecheck, build, Compose validation, and a Docker smoke test. Merge to `main` only after green gates; publish images tagged with the immutable commit SHA, then promote the same image through staging. See the [current architecture diagram](docs/wayfarer-architecture.html) for the system map. See `docs/learning-path.md` for the beginner route, `docs/api-security.md` for HTTP/API/security thinking, and `docs/ci-cd.md`, `docs/release-process.md`, and `jenkins/README.md` for shipping.
