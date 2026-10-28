# Release process

1. Create a feature branch and PR.
2. Wait for Jenkins quality gates and review.
3. Merge to `main`.
4. Build and publish the exact commit-SHA image (for example `registry.example/wayfarer:abc123`).
5. Promote that immutable image to staging with `docker compose`; smoke-test the home page and persistence.
6. Roll back by selecting the previous known-good SHA and restarting Compose. Never rebuild a mutable tag to recover.

This MVP has no production deployment automation and no Kubernetes files. Registry credentials belong in Jenkins credentials, never the repository.
