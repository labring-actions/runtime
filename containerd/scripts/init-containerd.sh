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
registry_domain=${1:-sealos.hub}
registry_port=${2:-5000}
readonly BIN_DIR=${BIN_DIR:-/usr/bin}

mkdir -p /opt/containerd && tar -zxf ../cri/libseccomp.tar.gz -C /opt/containerd
echo "/opt/containerd/lib" >/etc/ld.so.conf.d/containerd.conf
ldconfig
[ -d /etc/containerd/certs.d/ ] || mkdir /etc/containerd/certs.d/ -p
cp ../etc/containerd.service /etc/systemd/system/
tar -zxf ../cri/cri-containerd.tar.gz --strip-components 2 -C ${BIN_DIR}
if "$BIN_DIR/crun_" --version 2>/dev/null | grep ^crun; then
  cp -a "$BIN_DIR/crun_" "$BIN_DIR/crun"
  sed -i -E 's~default_runtime_name = ".+"~default_runtime_name = "crun"~' ../etc/config.toml
fi
# shellcheck disable=SC2046
chmod a+x $(tar -tf ../cri/cri-containerd.tar.gz | while read -r binary; do echo "${BIN_DIR}/${binary##*/}"; done | xargs)
systemctl enable containerd.service
cp ../etc/config.toml /etc/containerd
mkdir -p /etc/containerd/certs.d/$registry_domain:$registry_port
cp ../etc/hosts.toml /etc/containerd/certs.d/$registry_domain:$registry_port
systemctl daemon-reload
systemctl restart containerd.service
check_status containerd
logger "init containerd success"
