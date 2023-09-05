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
systemctl stop k3s
systemctl disable k3s
systemctl daemon-reload

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

rm -rf /usr/bin/{kubectl,crictl,ctr,k3s}
rm -f /etc/systemd/system/k3s.service
rm -rf /etc/systemd/system/k3s.service.d
rm -rf /etc/rancher/k3s
rm -rf /run/k3s
rm -rf /run/flannel
rm -rf /var/lib/rancher/k3s
rm -rf /var/lib/kubelet

bash killall.sh

logger "clean kubelet success"
