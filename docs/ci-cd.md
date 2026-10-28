# CI/CD

Jenkinsfile is a declarative PR/branch gate: `npm ci`, lint, TypeScript, Next build, both Compose config checks, then Docker build and HTTP smoke test. Configure a Multibranch Pipeline against the repository; do not store secrets in this file. The image tag is `wayfarer:$GIT_COMMIT`, never `latest`.

Jenkins-in-Docker is local/dev learning infrastructure only. Run `docker compose -f docker-compose.jenkins.yml up -d`; persistent controller data lives in `jenkins_home`. A local Jenkins agent needs Docker access for image builds, which is intentionally a documented local approach rather than a production security recommendation.
