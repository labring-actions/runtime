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
cd "$(dirname "$0")" >/dev/null 2>&1 || exit
source common.sh

# docker.service expects docker group and containerd runtime binaries.
# k8s 1.36 + cri-dockerd requires a complete docker runtime stack.
getent group docker >/dev/null 2>&1 || groupadd -r docker

if ! command_exists docker; then
  lsb_dist=$(get_distribution)
  lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
  echo "current system is $lsb_dist"
  case "$lsb_dist" in
  alios)
    ip link add name docker0 type bridge
    ip addr add dev docker0 172.17.0.1/16
    ;;
  esac

  [ -d /etc/docker/ ] || mkdir /etc/docker/ -p
  cp ../etc/docker.service /etc/systemd/system/
  tar --strip-components=1 -zxvf ../cri/docker.tgz -C /usr/bin
  # shellcheck disable=SC2046
  chmod a+x $(tar -tf ../cri/docker.tgz | while read -r binary; do echo "/usr/bin/${binary##*/}"; done | xargs)

  # verify required runtime binaries exist before starting docker
  command_exists containerd || { echo "containerd binary missing"; exit 1; }
  command_exists containerd-shim-runc-v2 || { echo "containerd-shim-runc-v2 binary missing"; exit 1; }

  systemctl enable docker.service
  systemctl restart docker.service
  cp ../etc/daemon.json /etc/docker
fi

systemctl daemon-reload
systemctl restart docker.service
check_status docker
logger "init docker success"
