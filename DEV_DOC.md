# Developer documentation

Prerequisites (inside VM)
- Docker and docker-compose must be installed and usable (root or sudo).

Setup
- Edit `srcs/.env` and set `LOGIN` and credentials.
- Ensure the host folder `/home/${LOGIN}/data` exists in the VM and is writable.

Build and run

```sh
make all        # builds images and starts containers
make down       # stop
make clean      # remove images and volumes
```

Files of interest
- `srcs/docker-compose.yml` - service definitions and volumes
- `srcs/requirements/*/Dockerfile` - service Dockerfiles
- `srcs/.env` - environment and credentials (do not commit real secrets)

Hostname
- To change the VM hostname to your login, run the provided `scripts/set_hostname.sh` inside the VM as root.
