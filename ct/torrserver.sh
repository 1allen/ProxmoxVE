#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/1allen/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: 1allen
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/YouROK/TorrServer

APP="TorrServer"
var_tags="${var_tags:-media;torrent;streaming}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if ! command -v docker &>/dev/null; then
    msg_error "No Docker Installation Found! (Is this the correct container?)"
    exit
  fi
  if ! docker ps -a --format '{{.Names}}' | grep -qx "torrserver"; then
    msg_error "No TorrServer container found (expected name: torrserver)."
    exit
  fi

  msg_info "Updating container OS"
  $STD apt-get update
  $STD apt-get -y upgrade
  msg_ok "Updated container OS"

  msg_info "Updating TorrServer container image"
  $STD docker pull ghcr.io/yourok/torrserver:latest
  $STD docker rm -f torrserver || true

  TS_DATA_DIR="/opt/torrserver"
  mkdir -p "${TS_DATA_DIR}/config" "${TS_DATA_DIR}/torrents" "${TS_DATA_DIR}/log"

  $STD docker run -d \
    --name torrserver \
    -p 8090:8090 \
    -e TS_PORT=8090 \
    -e TS_DONTKILL=1 \
    -e TS_HTTPAUTH=0 \
    -e TS_RDB=0 \
    -e TS_CONF_PATH=/opt/ts/config \
    -e TS_TORR_DIR=/opt/ts/torrents \
    -e TS_LOG_PATH=/opt/ts/log \
    -v "${TS_DATA_DIR}/config:/opt/ts/config" \
    -v "${TS_DATA_DIR}/torrents:/opt/ts/torrents" \
    -v "${TS_DATA_DIR}/log:/opt/ts/log" \
    --restart unless-stopped \
    ghcr.io/yourok/torrserver:latest

  $STD systemctl restart torrserver-container.service || true
  msg_ok "Updated TorrServer container"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8090${CL}"
