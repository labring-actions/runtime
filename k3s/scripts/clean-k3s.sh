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

rm -f /usr/bin/k3s-pre-start.sh
rm -f /usr/bin/k3s-post-stop.sh

sed -i '/ # sealos/d' /etc/sysctl.conf
sealos_b='### sealos begin ###'
sealos_e='### sealos end ###'
if grep -E "($sealos_b|$sealos_e)" /etc/security/limits.conf >/dev/null 2>&1; then
  slb=$(grep -nE "($sealos_b|$sealos_e)" /etc/security/limits.conf | head -n 1 | awk -F: '{print $1}')
  sle=$(grep -nE "($sealos_b|$sealos_e)" /etc/security/limits.conf | tail -n 1 | awk -F: '{print $1}')
  sed -i "${slb},${sle}d" /etc/security/limits.conf
fi


SYSTEM_NAME=k3s

BIN_DIR=/usr/bin

${BIN_DIR}/k3s-killall.sh

if command -v systemctl; then
    systemctl disable ${SYSTEM_NAME}
    systemctl reset-failed ${SYSTEM_NAME}
    systemctl daemon-reload
fi
if command -v rc-update; then
    rc-update delete ${SYSTEM_NAME} default
fi

rm -f /etc/systemd/system/k3s.service
rm -f /etc/rancher/k3s/*.env

remove_uninstall() {
    rm -f ${BIN_DIR}/k3s-uninstall.sh
}
trap remove_uninstall EXIT

if (ls /etc/systemd/system/k3s*.service || ls /etc/init.d/k3s*) >/dev/null 2>&1; then
    set +x; echo 'Additional k3s services installed, skipping uninstall of k3s'; set -x
    exit
fi

for cmd in kubectl crictl ctr; do
    if [ -L ${BIN_DIR}/$cmd ]; then
        rm -f ${BIN_DIR}/$cmd
    fi
done

rm -rf /etc/rancher/k3s
rm -rf /run/k3s
rm -rf /run/flannel
rm -rf /var/lib/rancher/k3s
rm -rf /var/lib/kubelet
rm -f ${BIN_DIR}/k3s

logger "clean kubelet success"
