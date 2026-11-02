# Release process

1. Create a feature branch and PR.
2. Update `CHANGELOG.md` under `## Unreleased` when the change requires an entry, following [the changelog policy](changelog-policy.md).
3. Wait for Jenkins quality gates and review.
4. Merge to `main`.
5. Build and publish the exact commit-SHA image (for example `registry.example/wayfarer:abc123`).
6. Promote that immutable image to staging with `docker compose`; smoke-test the home page and persistence.
7. Roll back by selecting the previous known-good SHA and restarting Compose. Never rebuild a mutable tag to recover.

This MVP has no production deployment automation and no Kubernetes files. Registry credentials belong in Jenkins credentials, never the repository.
