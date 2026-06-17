_This project has been created as part of the 42 curriculum by abdel._

---

## Description

Inception is a system administration project from the 42 curriculum. The goal is to broaden your knowledge of system administration by using Docker to set up a small infrastructure composed of different services, all running in dedicated containers inside a virtual machine.

The stack consists of:
- **NGINX** — the only entry point, listening on port 443 with TLS (HTTPS only)
- **WordPress** — the application server, running php-fpm, communicating with NGINX over a private Docker network
- **MariaDB** — the database backend, isolated from the outside world and only reachable by WordPress

Each service runs in its own custom-built Docker image (no pre-built images from Docker Hub are used). All containers restart automatically on failure and share persistent volumes so data survives restarts.

### Design choices

#### Virtual Machines vs Docker

A **virtual machine (VM)** emulates an entire computer, including a full operating system kernel, hardware drivers, and user-space. Each VM is isolated at the hypervisor level, which gives strong security guarantees but comes at a high resource cost — a typical VM consumes gigabytes of RAM and tens of gigabytes of disk just for the OS layer.

**Docker containers** share the host kernel; they isolate only the user-space (filesystem, network namespace, process tree) via Linux cgroups and namespaces. This makes containers start in milliseconds, use megabytes instead of gigabytes of RAM, and pack dozens of services onto a single machine. The trade-off is that a kernel vulnerability affects all containers on the host simultaneously, whereas VMs are fully separated.

For Inception the VM is the security boundary (mandated by the subject); Docker is used inside the VM purely to isolate services from each other and to make the stack reproducible. The combination gives the strong isolation of a VM with the operational convenience of containers.

#### Secrets vs Environment Variables

**Environment variables** are the simplest way to pass configuration to a process — every language and framework can read them with no extra tooling. The downside is that they are visible in plain text to any process that can read `/proc/<pid>/environ`, appear in `docker inspect` output, and are trivially leaked by logging frameworks that dump the environment.

**Docker secrets** (`docker secret create` in Swarm mode, or mounted files in Compose v3) place sensitive values in a tmpfs-mounted file (`/run/secrets/<name>`) accessible only to the container that needs it. The value never travels over the network in plain text and never appears in image layers or inspect output. The application must be written or configured to read from a file rather than an environment variable — a small code change with a significant security improvement.

This project uses **Docker secrets** (tmpfs-mounted files at `/run/secrets/<name>`). Passwords are never stored in `.env`, Dockerfiles, or image layers — only in `~/secrets/` on the host, owned by the user running Docker.

#### Docker Network vs Host Network

With **host networking** (`--network host`) a container shares the host's network namespace directly. The container sees all interfaces, binds ports on the host's IP, and enjoys native network throughput. The severe downside is zero isolation: a compromised container can reach any port on the host and any other container without restriction.

With a **Docker bridge network** (the default and what this project uses — `inception_net`) each container gets its own virtual network interface and a private IP in an isolated subnet. Containers can reach each other by service name (Docker's built-in DNS), but are invisible to the outside world unless ports are explicitly published. Only NGINX publishes a port (443) to the host; MariaDB and WordPress are completely internal.

This project uses a named bridge network (`inception_net`) so that:
- MariaDB is unreachable from outside the VM entirely
- WordPress is unreachable from outside the VM entirely
- Only NGINX is exposed, acting as a hardened reverse proxy

#### Docker Volumes vs Bind Mounts

A **bind mount** maps a specific path on the host filesystem into the container (`-v /host/path:/container/path`). The host retains full ownership and you can inspect or edit files directly with host tools. The downside is tight coupling to the host's directory layout, which makes the compose file non-portable across machines with different home directories or OS conventions.

A **Docker volume** (`docker volume create`) is managed by the Docker daemon and stored in `/var/lib/docker/volumes/`. Volumes are portable between compose stacks, support volume drivers (NFS, S3, encrypted block devices), and avoid permission mismatches between host and container UIDs.

This project uses **named Docker volumes** with the `local` driver and `bind` mount type. The volumes (`db_data`, `www_data`) are managed by Docker (visible to `docker volume ls` and `docker volume inspect`), but their data lives at `${HOST_DATA}/db` and `${HOST_DATA}/www` on the host so it survives container removal and is inspectable with host tools. The paths adapt to any login via the `HOST_DATA` variable in `.env`.

---

## Instructions

See [SETUP_VM.md](SETUP_VM.md) for the full step-by-step guide: creating the VM, installing Docker, transferring the repo, and configuring `/etc/hosts`.

Once the VM is ready and the repo is on it:

```sh
cp srcs/.env.example srcs/.env   # copy the template
nano srcs/.env                   # set LOGIN, DOMAIN_NAME, WP_ADMIN_USER, etc.
make secrets                     # create ~/secrets/ and store passwords
make dirs                        # create ~/data/db and ~/data/www
make all                         # build images and start containers
```

### Makefile targets

| Target | Action |
|--------|--------|
| `make all` | Build images then start containers in detached mode |
| `make build` | Build (or rebuild) all Docker images |
| `make up` | Start containers in detached mode |
| `make down` | Stop and remove containers |
| `make clean` | Stop containers, remove local images, volumes, and orphans |
| `make secrets` | Prompt for passwords and write them to `~/secrets/` |
| `make dirs` | Create `~/data/db` and `~/data/www`, fix ownership if needed |

---

## Resources

- [Docker documentation](https://docs.docker.com)
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [Docker secrets overview](https://docs.docker.com/engine/swarm/secrets/)
- [NGINX TLS configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [WordPress CLI (WP-CLI)](https://wp-cli.org/)
- [MariaDB Docker image conventions](https://mariadb.com/kb/en/docker-official-image/)
- [Linux namespaces — kernel docs](https://man7.org/linux/man-pages/man7/namespaces.7.html)
- [cgroups v2 overview](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html)

### AI usage

AI (Claude) was used for the following tasks:

- **Scaffolding** — generating initial Dockerfiles, entrypoint scripts, and the docker-compose skeleton so that manual effort could focus on understanding and customising rather than boilerplate.
- **Documentation** — drafting and structuring this README, including the comparison sections, based on prompts describing the project requirements.
- **Debugging** — diagnosing permission errors in volume mounts and TLS certificate path issues by describing symptoms and getting candidate explanations.

All generated output was reviewed, tested manually inside the VM, and adjusted where incorrect. AI was not used to make architectural decisions — those were determined by reading the project subject and Docker documentation directly.
