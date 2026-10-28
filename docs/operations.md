# Operations

Run `docker compose up -d --build`, inspect with `docker compose ps` and `docker compose logs -f app`, and verify `http://localhost:3000`. The app healthcheck requests `/`; a healthy response means the Next runtime is serving. Stop with `docker compose down`; `docker compose --profile db down -v` deletes educational database data.

Backups are not applicable to localStorage; users can use browser profile backups/export once that feature is added. Do not expose the Compose database port beyond localhost. Secrets are not committed; `.env.example` contains only non-secret settings. This project does not alter or require Kubernetes.
