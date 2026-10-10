# Assignment 2 Dockerized Diagnostic CLI

A Bash diagnostic tool packaged as a small Docker image (Alpine + bash) that can
be built and run locally with plain Docker or Docker Compose. No cloud services
are involved.

## Repository layout

```
assignment-2/
├── README.md
├── app/
│   ├── diagnostic.sh     # the CLI (system | network <host> | disk | help)
│   └── health-check.sh   # checks the tool inside the image is healthy
├── Dockerfile
├── compose.yaml
├── .dockerignore
├── test.sh               # Docker-based test suite
└── grade.sh              # local grading script
```

## Installation / setup

Requirements: Docker Engine with the Compose plugin (`docker compose`).

```bash
git clone <your-repository-url>
cd <repository>
chmod +x grade.sh test.sh app/*.sh
docker build -t diagnostic-tool .
```

## Usage

```bash
docker run --rm diagnostic-tool system            # OS, kernel, CPU, memory, uptime
docker run --rm diagnostic-tool disk              # df -h output
docker run --rm diagnostic-tool network localhost # resolve + ping a host
docker run --rm diagnostic-tool help              # usage
docker run --rm diagnostic-tool                   # no argument -> help (default CMD)
```

With Docker Compose:

```bash
docker compose run --rm diagnostic system
docker compose run --rm diagnostic network example.com
docker compose run --rm diagnostic disk
docker compose run --rm diagnostic help
```

Run the built-in health check:

```bash
docker run --rm --entrypoint /app/health-check.sh diagnostic-tool
```

### Exit codes

| Code | Meaning                                                             |
|------|---------------------------------------------------------------------|
| 0    | success                                                             |
| 1    | operational failure (host does not resolve, no ping reply, df fails) |
| 2    | invalid command, missing argument or invalid input                  |

## Design notes

- **Base image:** `alpine:3.20` — tiny and quick to pull.
- **Packages:** only `bash` is installed (`--no-cache`); busybox covers the rest.
- **Non-root:** the container runs as the unprivileged user `diag`.
- **ENTRYPOINT + CMD:** the entrypoint is the CLI, so arguments after the image
  name go straight to the tool; `CMD ["help"]` is the default.
- **.dockerignore:** keeps `.git`, logs, temp files, docs and tests out of the
  build context.
- **Compose:** `read_only: true` because the tool never writes to disk.

## Testing

```bash
./test.sh      # builds a test image and runs 9 checks
./grade.sh     # full local grader (needs Docker)
bash -n app/*.sh test.sh grade.sh   # syntax check
```

`test.sh` covers: help, default command, system, disk, invalid command,
missing host, invalid host, extra arguments and the health check.

## Assumptions

- Docker (with the `docker compose` plugin) is installed and the daemon is running.
- Containers may not be allowed to send ICMP. In that case `network` prints
  "ping skipped" instead of failing, as long as the host resolved.
- Network commands need outbound access only for external hostnames;
  `localhost` works offline.
- No secrets or machine-specific values are stored in the repository.

## Git workflow

Developed on a feature branch (`feature/docker`) with small commits and merged
into `main`.
