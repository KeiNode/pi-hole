`install.sh` and `uninstall.sh` are responsible for managing containers, networks (optional), and persistent data. They are designed to easily follow Pi-hole image versions by changing the image tag via a variable.

---

## OS Support
- **Ubuntu** (LTS recommended)
- **Debian** (stable recommended)

Note: This repo targets **non-RedHat**.

---

## Purpose
- Run Pi-hole in Docker with persistent data (volumes or host mounts).
- Simple, readable, and easy to upgrade: Pi-hole versions are controlled by the `PIHOLE_TAG` / `PIHOLE_IMAGE` variables.
- Scripts are designed to be run directly from the `pi-hole/` root.

---

## Important variables (can be set via `.env` or export)
- `PIHOLE_IMAGE` — image name (default: `pihole/pihole`)
- `PIHOLE_TAG` — image tag (default: `latest`)
- `TZ` — timezone (example: `Asia/Jakarta`)
- `WEBPASSWORD` — Web UI admin password (optional; blank = prompt/auto)
- `HOST_PORT_DNS_TCP` / `HOST_PORT_DNS_UDP` — host DNS port (default 53)
- `HOST_PORT_WEB` — Web UI port (default 80)
- `CONTAINER_NAME` — container name (default: `pihole`)
- `DATA_DIR` — host directory for persistence (default: `./pihole_data`)
- `PUID` / `PGID` — user/group mapping (optional)
