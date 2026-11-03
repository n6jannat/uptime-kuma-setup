#!/usr/bin/env bash
#
# install.sh - install Docker (if needed) and start Uptime Kuma.
#
# Usage:
#   ./install.sh            # HTTP on port 3001
#   ./install.sh --https    # HTTPS via Caddy (set DOMAIN in .env first)

set -euo pipefail
cd "$(dirname "$0")"

HTTPS=false
[[ "${1:-}" == "--https" ]] && HTTPS=true

SUDO=""
[[ $EUID -ne 0 ]] && SUDO="sudo"

if ! command -v docker >/dev/null 2>&1; then
    echo "==> Installing Docker"
    curl -fsSL https://get.docker.com | $SUDO sh
    $SUDO systemctl enable --now docker
fi

if ! docker compose version >/dev/null 2>&1 && ! $SUDO docker compose version >/dev/null 2>&1; then
    echo "Error: 'docker compose' plugin not found. Install docker-compose-plugin." >&2
    exit 1
fi

if [[ ! -f .env ]]; then
    echo "==> Creating .env from .env.example"
    cp .env.example .env
fi
mkdir -p data

if [[ "$HTTPS" == true ]]; then
    # shellcheck source=/dev/null
    source .env
    if [[ -z "${DOMAIN:-}" || "$DOMAIN" == "status.example.com" ]]; then
        echo "Error: set DOMAIN in .env to your real domain before using --https" >&2
        exit 1
    fi
    sed -i 's/^KUMA_BIND=.*/KUMA_BIND=127.0.0.1/' .env
    echo "==> Starting Uptime Kuma with HTTPS for $DOMAIN"
    $SUDO docker compose --profile https up -d
    URL="https://$DOMAIN"
else
    echo "==> Starting Uptime Kuma"
    $SUDO docker compose up -d
    IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
    URL="http://${IP:-localhost}:$(grep -E '^KUMA_PORT=' .env | cut -d= -f2)"
fi

echo "==> Waiting for Uptime Kuma to start"
for _ in $(seq 1 60); do
    status="$($SUDO docker inspect -f '{{.State.Health.Status}}' uptime-kuma 2>/dev/null || echo starting)"
    [[ "$status" == "healthy" ]] && break
    sleep 2
done

echo
echo "Uptime Kuma is running ($status)."
echo "Open $URL and create your admin account."
