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


source common.sh
disable_firewalld

# Annotate system configuration
if [[ "$(get_distribution)" = "kylin" ]]; then
  cat ../etc/sysctl.d/*.conf | sort | uniq | while read -r str; do
    k=${str%=*}
    v=${str#*=}
    if [ "$k" != "$v" ] && ! grep "$k" /etc/sysctl.conf >/dev/null 2>&1; then
      echo "$k=$v # sealos"
    fi
  done >>/etc/sysctl.conf
else
  cp -rf ../etc/sysctl.d/* /etc/sysctl.d/
  bash /usr/bin/kubelet-pre-start.sh
fi

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
