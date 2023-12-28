#!/bin/bash
# Copyright © 2022 sealos.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

timestamp() {
  date +"%Y-%m-%d %T"
}

error() {
  flag=$(timestamp)
  echo -e "\033[31m ERROR [$flag] >> $* \033[0m"
  exit 1
}

logger() {
  flag=$(timestamp)
  echo -e "\033[36m INFO [$flag] >> $* \033[0m"
}

warn() {
  flag=$(timestamp)
  echo -e "\033[33m WARN [$flag] >> $* \033[0m"
}

debug() {
  flag=$(timestamp)
  echo -e "\033[32m DEBUG [$flag] >> $* \033[0m"
}

check_service() {
  local action=$1
  shift
  systemctl daemon-reload
  case $action in
  start)
    systemctl enable "$@"
    ;;
  stop)
    systemctl disable "$@"
    ;;
  *)
    error "service action error, only start/stop."
    ;;
  esac
  systemctl "$action" "$@"
}

check_status() {
  for unit; do
    logger "Health check $unit!"
    status=$(systemctl status "$unit" | grep Active | awk '{print $3}')
    if [[ $status = "(running)" ]]; then
      logger "$unit is running"
    else
      error "$unit status is error"
    fi
  done
}

ubuntu_dns() {
  os="$(. /etc/os-release && echo "$ID")"
  if echo "$os" | grep "ubuntu" >/dev/null 2>&1; then
    if systemctl status systemd-resolved.service >/dev/null 2>&1; then
      systemctl stop systemd-resolved.service
      systemctl disable systemd-resolved.service
      rm /etc/resolv.conf
      cp /run/systemd/resolve/resolv.conf /etc/resolv.conf
    fi
    logger "steup operation_ubuntu finished"
  fi
}

version_ge() {
  test "$(echo "$@" | tr ' ' '\n' | sort -rV | head -n 1)" == "$1"
}

get_distribution() {
  lsb_dist=""
  # Every system that we officially support has /etc/os-release
  if [ -r /etc/os-release ]; then
    lsb_dist="$(. /etc/os-release && echo "$ID")"
  fi
  # Returning an empty string here should be alright since the
  # case statements don't act unless you provide an actual value
  echo "$lsb_dist"
}

disable_firewalld() {
  lsb_dist=$(get_distribution)
  lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
  case "$lsb_dist" in
  ubuntu | deepin | debian | raspbian)
    command -v ufw &>/dev/null && ufw disable
    ;;
  centos | rhel | ol | sles | kylin | neokylin)
    systemctl stop firewalld && systemctl disable firewalld
    ;;
  *)
    systemctl stop firewalld && systemctl disable firewalld
    echo "unknown system, use default to stop firewalld"
    ;;
  esac
}

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

check_cmd_exits() {
  for cmd; do
    if which "$cmd"; then
      error "The machine $cmd is not clean. Please clean $cmd the system."
    fi
  done
}

check_file_exits() {
  for f; do
    if [[ -f $f ]]; then
      error "The machine $f is not clean. Please clean $f the system."
    fi
  done
}

check_port_inuse() {
  readonly BIN_DIR=${BIN_DIR:-/usr/bin}
  if ! command_exists lsof; then
    cp -au ../opt/lsof ${BIN_DIR}
  fi
  logger "Check port kubelet port 10249..10259, reserved port 5050..5054 inuse. Please wait..."
  for port in {10249..10259} {5050..5054}; do
    portOut="$(lsof -i :"${port}")"
    if [ -n "$portOut" ]; then
      error "Port: $port occupied. Please turn off port service."
    fi
  done
}
