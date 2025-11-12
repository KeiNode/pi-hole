#!/usr/bin/env bash
# install.sh - Pi-hole (Docker) installer for Debian/Ubuntu
# NOTE: This script is intended for regular OS installs (not LXC CT).
# Supports: Ubuntu, Debian
# Default web admin password: admin123

set -euo pipefail
IFS=$'\n\t'

# --- Colors ---
PURPLE="\e[35m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"
CHECK_MARK="\u2714"
CROSS_MARK="\u2718"

# --- Banner (purple) ---
print_banner() {
  echo -e "${PURPLE} /$$$$$$$$ /$$$$$$  /$$   /$$       /$$  /$$          /$$   /$$  /$$$$$$  /$$       /$$$$$$$$"
  echo -e "| $$_____//$$__  $$| $$$ | $$      |  $$|  $$        | $$  | $$ /$$__  $$| $$      | $$_____/"
  echo -e "| $$     | $$  \ $$| $$$$| $$       \  $$\  $$       | $$  | $$| $$  \ $$| $$      | $$      "
  echo -e "| $$$$$  | $$$$$$$$| $$ $$ $$        \  $$\  $$      | $$$$$$$$| $$  | $$| $$      | $$$$$   "
  echo -e "| $$__/  | $$__  $$| $$  $$$$         /$$/ /$$/      | $$__  $$| $$  | $$| $$      | $$__/   "
  echo -e "| $$     | $$  | $$| $$\  $$$        /$$/ /$$/       | $$  | $$| $$  | $$| $$      | $$      "
  echo -e "| $$     | $$  | $$| $$ \  $$       /$$/ /$$/        | $$  | $$|  $$$$$$/| $$$$$$$$| $$$$$$$$"
  echo -e "|__/     |__/  |__/|__/  \__/      |__/ |__/         |__/  |__/ \______/ |________/|________/"
  echo -e "                                                                                             "
  echo -e "                                                                                             ${RESET}"
}

info()    { echo -e "${YELLOW}[INFO] ${1}${RESET}"; }
success() { echo -e "${GREEN}[OK] ${1}${RESET}"; }
fail()    { echo -e "${RED}[ERROR] ${1}${RESET}"; exit 1; }

prompt_yes() {
  local prompt_text="$1"
  read -r -p "${prompt_text} [Y/n]: " answer
  answer=${answer:-Y}
  case "$answer" in
    [Yy]* ) return 0 ;;
    * ) return 1 ;;
  esac
}

# --- Auto-detect OS ---
detect_os() {
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    OS_ID=${ID:-unknown}
    OS_NAME=${NAME:-unknown}
    OS_VERSION=${VERSION_ID:-unknown}
  else
    OS_ID="unknown"
    OS_NAME="unknown"
    OS_VERSION="unknown"
  fi

  case "$OS_ID" in
    ubuntu|debian)
      success "Detected OS: $OS_NAME $OS_VERSION"
      ;;
    *)
      fail "Unsupported OS: $OS_NAME ($OS_ID). This installer supports only Ubuntu and Debian (non-RedHat)."
      ;;
  esac
}

# --- Check and install Docker if missing ---
install_docker_if_missing() {
  if command -v docker >/dev/null 2>&1; then
    success "Docker is already installed"
    return 0
  fi

  info "Docker not found — attempting installation (requires sudo)"
  if [[ $(id -u) -ne 0 ]]; then
    sudo_cmd="sudo"
  else
    sudo_cmd=""
  fi

  # Minimal install steps for Debian/Ubuntu
  ${sudo_cmd} apt-get update -y
  ${sudo_cmd} apt-get install -y ca-certificates curl gnupg lsb-release

  # Add Docker official GPG key and repo
  curl -fsSL https://download.docker.com/linux/${OS_ID}/gpg | ${sudo_cmd} gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "\n
deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/${OS_ID} $(lsb_release -cs) stable" | ${sudo_cmd} tee /etc/apt/sources.list.d/docker.list > /dev/null

  ${sudo_cmd} apt-get update -y
  ${sudo_cmd} apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

  if command -v docker >/dev/null 2>&1; then
    success "Docker installation succeeded"
  else
    fail "Docker installation failed — please install Docker manually and re-run this script"
  fi
}

# --- Main installation steps ---
main() {
  print_banner
  detect_os

  if ! prompt_yes "Do you want to proceed with Installation?"; then
    info "Installation cancelled by user. Exiting."
    exit 0
  fi

  # -----------------
  # Configuration (defaults)
  # -----------------
  PIHOLE_IMAGE_DEFAULT="pihole/pihole"
  PIHOLE_TAG_DEFAULT="latest"
  TZ_DEFAULT="Asia/Jakarta"
  WEBPASSWORD_DEFAULT="admin123"
  CONTAINER_NAME_DEFAULT="pihole"
  DATA_DIR_DEFAULT="$(pwd)/pihole_data"
  HOST_PORT_DNS_UDP_DEFAULT=53
  HOST_PORT_DNS_TCP_DEFAULT=53
  HOST_PORT_WEB_DEFAULT=80

  read -r -p "Image (default ${PIHOLE_IMAGE_DEFAULT}): " PIHOLE_IMAGE
  PIHOLE_IMAGE=${PIHOLE_IMAGE:-$PIHOLE_IMAGE_DEFAULT}

  read -r -p "Tag (default ${PIHOLE_TAG_DEFAULT}): " PIHOLE_TAG
  PIHOLE_TAG=${PIHOLE_TAG:-$PIHOLE_TAG_DEFAULT}

  read -r -p "Timezone (default ${TZ_DEFAULT}): " TZ
  TZ=${TZ:-$TZ_DEFAULT}

  read -r -p "Web UI password (default kept hidden) [press Enter to use default]: " -s WEBPASSWORD_INPUT
  echo
  WEBPASSWORD=${WEBPASSWORD_INPUT:-$WEBPASSWORD_DEFAULT}

  read -r -p "Container name (default ${CONTAINER_NAME_DEFAULT}): " CONTAINER_NAME
  CONTAINER_NAME=${CONTAINER_NAME:-$CONTAINER_NAME_DEFAULT}

  read -r -p "Host data directory (default ${DATA_DIR_DEFAULT}): " DATA_DIR
  DATA_DIR=${DATA_DIR:-$DATA_DIR_DEFAULT}

  read -r -p "Host DNS UDP port (default ${HOST_PORT_DNS_UDP_DEFAULT}): " HOST_PORT_DNS_UDP
  HOST_PORT_DNS_UDP=${HOST_PORT_DNS_UDP:-$HOST_PORT_DNS_UDP_DEFAULT}

  read -r -p "Host DNS TCP port (default ${HOST_PORT_DNS_TCP_DEFAULT}): " HOST_PORT_DNS_TCP
  HOST_PORT_DNS_TCP=${HOST_PORT_DNS_TCP:-$HOST_PORT_DNS_TCP_DEFAULT}

  read -r -p "Host Web port (default ${HOST_PORT_WEB_DEFAULT}): " HOST_PORT_WEB
  HOST_PORT_WEB=${HOST_PORT_WEB:-$HOST_PORT_WEB_DEFAULT}

  # Summary
  info "Configuration summary:"
  echo "  Image: ${PIHOLE_IMAGE}:${PIHOLE_TAG}"
  echo "  Timezone: ${TZ}"
  echo "  Web UI password: (hidden)"
  echo "  Container name: ${CONTAINER_NAME}"
  echo "  Data directory: ${DATA_DIR}"
  echo "  Ports: DNS udp ${HOST_PORT_DNS_UDP}, DNS tcp ${HOST_PORT_DNS_TCP}, Web ${HOST_PORT_WEB}"

  # Ensure Docker available
  install_docker_if_missing

  # Prepare data directories
  info "Preparing data directories"
  mkdir -p "${DATA_DIR}/etc-pihole" "${DATA_DIR}/etc-dnsmasq.d"
  # set permissive ownership so container can write (best effort)
  if [[ $(id -u) -ne 0 ]]; then
    sudo chown -R 1000:1000 "${DATA_DIR}" || true
  else
    chown -R 1000:1000 "${DATA_DIR}" || true
  fi
  success "Data directories ready ${CHECK_MARK}"

  # Create docker network if not exists
  if ! docker network ls --format "{{.Name}}" | grep -q "pihole_net"; then
    info "Creating docker network: pihole_net"
    docker network create pihole_net || true
  fi

  # Pull image
  info "Pulling Pi-hole image: ${PIHOLE_IMAGE}:${PIHOLE_TAG}"
  if docker pull "${PIHOLE_IMAGE}:${PIHOLE_TAG}"; then
    success "Image pulled ${CHECK_MARK}"
  else
    echo -e "${RED}Failed to pull image. Exiting.${RESET}"
    exit 1
  fi

  # Stop and remove existing container if exists
  if docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    info "Stopping existing container: ${CONTAINER_NAME}"
    docker stop "${CONTAINER_NAME}" || true
    docker rm "${CONTAINER_NAME}" || true
  fi

  # Run container
  info "Starting Pi-hole container..."
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --network pihole_net \
    -p "${HOST_PORT_DNS_TCP}":53/tcp -p "${HOST_PORT_DNS_UDP}":53/udp \
    -p "${HOST_PORT_WEB}":80 \
    -v "${DATA_DIR}/etc-pihole:/etc/pihole" \
    -v "${DATA_DIR}/etc-dnsmasq.d:/etc/dnsmasq.d" \
    -e TZ="${TZ}" \
    -e WEBPASSWORD="${WEBPASSWORD}" \
    -e DNSMASQ_LISTENING="all" \
    --restart unless-stopped \
    "${PIHOLE_IMAGE}:${PIHOLE_TAG}"

  sleep 4

  if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    success "Container is running ${CHECK_MARK}"
  else
    echo -e "${RED}Container failed to start. See 'docker logs ${CONTAINER_NAME}' for details.${RESET}"
    exit 1
  fi

  # Wait for Pi-hole web interface to be reachable (basic check)
  info "Waiting for Pi-hole web interface to be ready (checking /admin)..."
  ready=false
  for i in {1..20}; do
    if curl -s -I --max-time 3 "http://127.0.0.1:${HOST_PORT_WEB}/admin" | grep -q "200"; then
      ready=true
      break
    fi
    sleep 3
  done

  if $ready; then
    success "Pi-hole web UI reachable${CHECK_MARK}"
  else
    info "Web UI not reachable via 127.0.0.1:${HOST_PORT_WEB} — it may still be initializing. Check container logs if necessary."
  fi

  # Ensure password is set (the image respects WEBPASSWORD env var on first run)
  info "Setting admin password (if not set)"
  docker exec -it "${CONTAINER_NAME}" sudo pihole -a -p "${WEBPASSWORD}" >/dev/null 2>&1 || true
  success "Admin password set (default or chosen) ${CHECK_MARK}"

  echo
  echo -e "${GREEN}INSTALLATION SUCCESSFULLY YEAYYYY${RESET}"
  echo
  echo "Access the Pi-hole dashboard:" 
  echo "  Web UI: http://<HOST_IP>:${HOST_PORT_WEB}/admin"
  echo "  Username: admin"
  echo "  Password: ${WEBPASSWORD}"
  echo
  echo "Useful commands:"
  echo "  docker logs -f ${CONTAINER_NAME}        # view runtime logs"
  echo "  docker exec -it ${CONTAINER_NAME} /bin/bash  # enter container shell"
  echo
  echo "Notes:"
  echo "  - This installer targets Ubuntu/Debian (not LXC CT)."
  echo "  - Data directory: ${DATA_DIR}"
  echo "  - To uninstall, run your provided uninstall.sh (not included in this script)."
  echo
}

main "$@"
