# CI/CD Pipeline Automation

An end-to-end CI/CD pipeline: a GitHub push automatically triggers Jenkins to
test, containerize, and deploy a Node.js app to AWS EC2 with zero downtime,
behind an Nginx reverse proxy terminating SSL/TLS.

## Architecture

```
Dev pushes to GitHub
        |
        v  (webhook)
Jenkins (Docker container, local)
        |
        |-- Checkout
        |-- Install & Test   (npm ci && npm test, inside a node:20-alpine container)
        |-- Build Image      (multi-stage Dockerfile, tagged with git short SHA)
        |-- Push Image       (Docker Hub)
        |
        v  (SSH)
EC2 deploy target
        |
        |-- Pull new image
        |-- Start new container on the standby port (3000 <-> 3001)
        |-- Health-check it (/health)
        |-- Rewrite Nginx's upstream.conf + reload (zero-downtime swap)
        |-- Stop the old container
        |
        v
Nginx (Docker, --network host)
        |-- :80  -> 301 redirect to :443
        |-- :443 -> SSL/TLS termination (self-signed cert) -> reverse proxy to app
```

## Why these choices

- **Jenkins runs locally in Docker** with the host's Docker socket mounted in,
  so it can run `docker build`/`push` against the real Docker engine without
  a nested Docker-in-Docker setup.
- **GitHub webhook via ngrok tunnel.** Local Jenkins has no public IP, so a
  tunnel exposes it for real-time webhook delivery instead of polling.
- **Images tagged by git short SHA**, not just `latest` — every deployment is
  traceable back to an exact commit.
- **Zero-downtime deploys**: the new container starts and is health-checked
  *before* Nginx's upstream is switched to it (via a graceful `nginx -s reload`,
  which finishes in-flight requests instead of dropping them). The old
  container is only stopped after traffic has moved. Verified empirically:
  156/156 requests succeeded with zero failures during a live deploy.
- **Nginx runs with `--network host`** so it can reach the app container via
  `127.0.0.1` on the EC2 host — containers otherwise have isolated networks.
- **Self-signed TLS certificate** since this deploy target has no domain name;
  the cert still provides real encryption, just without a trusted CA chain
  (browsers will show a warning, which is expected and fine for this demo).

## Repo layout

```
app/            Express app + Jest/Supertest tests
jenkins/        Custom Jenkins image (adds Docker CLI)
deploy/         EC2 user-data (installs Docker) and the zero-downtime deploy script
nginx/          Reverse proxy config (app.conf) and the upstream file the deploy script rewrites
Jenkinsfile     The pipeline itself
docker-compose.yml   Local dev
```

## Running it locally

```bash
docker compose up --build
curl http://localhost:3000/
curl http://localhost:3000/health
```

## Reproducing the full pipeline

1. Jenkins (local, Docker): `jenkins/Dockerfile` extends `jenkins/jenkins:lts` with the Docker CLI.
2. Credentials needed in Jenkins: `dockerhub-credentials` (username+token) and `ec2-ssh-key` (SSH private key).
3. EC2 deploy target: Amazon Linux 2023, Docker installed via `deploy/user-data.sh`, security group open on 22 (admin IP)/80/443.
4. Nginx + self-signed cert set up once on the server (see `nginx/conf.d/`).
5. GitHub webhook -> ngrok tunnel -> Jenkins job with "GitHub hook trigger for GITScm polling" enabled.

## Cost note

Everything here (EC2 t3.micro, data transfer) fits comfortably within AWS
Free Tier for a personal account used intermittently like this project was.
