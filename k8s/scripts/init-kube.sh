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

# localhost for hosts
grep 127.0.0.1 <(grep localhost /etc/hosts) || echo "127.0.0.1 localhost" >>/etc/hosts
grep ::1 <(grep localhost /etc/hosts) || echo "::1 localhost" >>/etc/hosts

cp -a ../scripts/kubelet-pre-start.sh /usr/bin
cp -a ../scripts/kubelet-post-stop.sh /usr/bin
cp -rf ../etc/sysctl.d/* /etc/sysctl.d/

# Annotate system configuration
if [[ -f "/etc/sysctl.conf" ]]; then
  for configName in $(awk -F'=' '!/^($|#)/{print $1}' /etc/sysctl.d/sealos-k8s.conf | awk '$1=$1'); do 
    sed -i "/^${configName}=/s/^/# /" /etc/sysctl.conf
  done
fi

bash /usr/bin/kubelet-pre-start.sh

source common.sh
disable_firewalld

cp -a ../bin/* /usr/bin
#need after cri-shim
crictl pull ${registryDomain}:${registryPort}/${sandboxImage}
mkdir -p /etc/systemd/system
cp ../etc/kubelet.service /etc/systemd/system/
[ -d /etc/systemd/system/kubelet.service.d ] || mkdir /etc/systemd/system/kubelet.service.d
cp ../etc/10-kubeadm.conf /etc/systemd/system/kubelet.service.d/
[ -d /var/lib/kubelet ] || mkdir /var/lib/kubelet
systemctl enable kubelet
logger "init kubelet success"
