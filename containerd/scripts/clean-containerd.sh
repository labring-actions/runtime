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
storage=${1:-/var/lib/containerd}
readonly BIN_DIR=${BIN_DIR:-/usr/bin}
systemctl stop containerd
systemctl disable containerd
rm -rf /etc/containerd
rm -rf /etc/systemd/system/containerd.service
systemctl daemon-reload
rm -rf $storage
rm -rf /run/containerd/containerd.sock
rm -rf /var/lib/nerdctl

rm -f ${BIN_DIR}/containerd
rm -f ${BIN_DIR}/containerd-stress
rm -f ${BIN_DIR}/containerd-shim
rm -f ${BIN_DIR}/containerd-shim-runc-v1
rm -f ${BIN_DIR}/containerd-shim-runc-v2
rm -f ${BIN_DIR}/crictl
rm -f /etc/crictl.yaml
rm -f ${BIN_DIR}/ctr
rm -f ${BIN_DIR}/ctd-decoder
rm -f ${BIN_DIR}/runc
rm -f ${BIN_DIR}/nerdctl

rm -rf /opt/containerd
rm -rf /etc/ld.so.conf.d/containerd.conf
ldconfig

logger "clean containerd success"
