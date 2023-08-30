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
systemctl stop kubelet
systemctl daemon-reload

rm -f /usr/bin/conntrack
rm -f /usr/bin/kubelet-pre-start.sh
rm -f /usr/bin/kubelet-post-stop.sh
rm -f /usr/bin/kubeadm
rm -f /usr/bin/kubectl
rm -f /usr/bin/kubelet

sed -i '/ # sealos/d' /etc/sysctl.conf
sealos_b='### sealos begin ###'
sealos_e='### sealos end ###'
if grep -E "($sealos_b|$sealos_e)" /etc/security/limits.conf >/dev/null 2>&1; then
  slb=$(grep -nE "($sealos_b|$sealos_e)" /etc/security/limits.conf | head -n 1 | awk -F: '{print $1}')
  sle=$(grep -nE "($sealos_b|$sealos_e)" /etc/security/limits.conf | tail -n 1 | awk -F: '{print $1}')
  sed -i "${slb},${sle}d" /etc/security/limits.conf
fi
rm -f /etc/systemd/system/kubelet.service
rm -rf /etc/systemd/system/kubelet.service.d
rm -rf /var/lib/kubelet/
logger "clean kubelet success"
