#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: 1allen
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/YouROK/TorrServer

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

TS_IMAGE="${TS_IMAGE:-ghcr.io/yourok/torrserver:latest}"
TS_CONTAINER_NAME="${TS_CONTAINER_NAME:-torrserver}"
TS_HOST_PORT="${TS_HOST_PORT:-8090}"
TS_PORT="${TS_PORT:-8090}"
TS_DATA_DIR="${TS_DATA_DIR:-/opt/torrserver}"

TS_CONF_PATH="${TS_CONF_PATH:-/opt/ts/config}"
TS_TORR_DIR="${TS_TORR_DIR:-/opt/ts/torrents}"
TS_LOG_PATH="${TS_LOG_PATH:-/opt/ts/log}"

TS_HTTPAUTH="${TS_HTTPAUTH:-0}"
TS_RDB="${TS_RDB:-0}"
TS_DONTKILL="${TS_DONTKILL:-1}"

TS_AUTH_USER="${TS_AUTH_USER:-admin}"
TS_AUTH_PASS="${TS_AUTH_PASS:-changeme}"

msg_info "Installing dependencies"
$STD apt-get install -y ca-certificates curl gnupg
msg_ok "Installed dependencies"

msg_info "Installing Docker"
if ! command -v docker &>/dev/null; then
  $STD apt-get install -y docker.io
fi
$STD systemctl enable -q --now docker
msg_ok "Installed Docker"

msg_info "Preparing persistent directories"
mkdir -p "${TS_DATA_DIR}/config" "${TS_DATA_DIR}/torrents" "${TS_DATA_DIR}/log"
msg_ok "Prepared persistent directories"

if [[ "${TS_HTTPAUTH}" == "1" ]] && [[ ! -f "${TS_DATA_DIR}/config/accs.db" ]]; then
  msg_info "Creating HTTP auth file (accs.db)"
  cat >"${TS_DATA_DIR}/config/accs.db" <<EOF
{
  "${TS_AUTH_USER}": "${TS_AUTH_PASS}"
}
EOF
  chmod 600 "${TS_DATA_DIR}/config/accs.db"
  msg_ok "Created HTTP auth file (accs.db)"
fi

msg_info "Pulling TorrServer image"
$STD docker pull "${TS_IMAGE}"
msg_ok "Pulled TorrServer image"

if docker ps -a --format '{{.Names}}' | grep -qx "${TS_CONTAINER_NAME}"; then
  msg_info "Removing existing container (${TS_CONTAINER_NAME})"
  $STD docker rm -f "${TS_CONTAINER_NAME}"
  msg_ok "Removed existing container"
fi

msg_info "Creating TorrServer container"
$STD docker run -d \
  --name "${TS_CONTAINER_NAME}" \
  -p "${TS_HOST_PORT}:${TS_PORT}" \
  -e "TS_PORT=${TS_PORT}" \
  -e "TS_DONTKILL=${TS_DONTKILL}" \
  -e "TS_HTTPAUTH=${TS_HTTPAUTH}" \
  -e "TS_RDB=${TS_RDB}" \
  -e "TS_CONF_PATH=${TS_CONF_PATH}" \
  -e "TS_TORR_DIR=${TS_TORR_DIR}" \
  -e "TS_LOG_PATH=${TS_LOG_PATH}" \
  -v "${TS_DATA_DIR}/config:${TS_CONF_PATH}" \
  -v "${TS_DATA_DIR}/torrents:${TS_TORR_DIR}" \
  -v "${TS_DATA_DIR}/log:${TS_LOG_PATH}" \
  --restart unless-stopped \
  "${TS_IMAGE}"
msg_ok "Created TorrServer container"

msg_info "Saving version info"
docker inspect "${TS_IMAGE}" --format '{{.Id}}' | cut -d: -f2 | head -c12 >/opt/torrserver_version.txt
msg_ok "Saved version info"

msg_info "Creating systemd service"
cat >/etc/systemd/system/torrserver-container.service <<EOF
[Unit]
Description=TorrServer (Docker container)
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker start ${TS_CONTAINER_NAME}
ExecStop=/usr/bin/docker stop ${TS_CONTAINER_NAME}
ExecReload=/usr/bin/docker restart ${TS_CONTAINER_NAME}
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

$STD systemctl daemon-reload
$STD systemctl enable -q --now torrserver-container.service
msg_ok "Created systemd service"

motd_ssh
customize
cleanup_lxc
