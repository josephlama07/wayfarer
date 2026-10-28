# Jenkins local setup

This Compose file runs Jenkins controller for local learning only, not production. By default it binds Jenkins HTTP to port `8080`; if that port is occupied, choose another host port without editing the file:

```bash
JENKINS_HTTP_PORT=8081 docker compose -f docker-compose.jenkins.yml up -d
```

Then open `http://127.0.0.1:8081`. Start it with `docker compose -f docker-compose.jenkins.yml up -d`, open the configured port, and create a Multibranch Pipeline pointed at the repository. Install the plugins listed in `plugins.txt` (or use the Jenkins setup wizard). The controller needs a Docker-capable agent to run the Docker stages; a common local-only approach is a dedicated agent with the host Docker socket, accepting the security tradeoff. Keep credentials in Jenkins credentials and destroy the environment when finished.
