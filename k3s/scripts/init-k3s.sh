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

cp -a ../scripts/k3s-pre-start.sh /usr/bin
cp -a ../scripts/k3s-post-stop.sh /usr/bin

source common.sh
disable_firewalld

# Annotate system configuration
cat ../etc/sysctl.d/*.conf | sort | uniq | while read -r str; do
  k=${str%=*}
  v=${str#*=}
  echo "$k=$v # sealos"
done >>/etc/sysctl.conf
bash /usr/bin/kubelet-pre-start.sh
sealos_b='### sealos begin ###'
sealos_e='### sealos end ###'
if ! grep -E "($sealos_b|$sealos_e)" /etc/security/limits.conf >/dev/null 2>&1; then
  {
    echo "$sealos_b"
    cat ../etc/limits.d/*.conf | grep -v ^# | grep -v ^$ | awk '{print $1,$2,$3,$4}'
    echo "$sealos_e"
  } >>/etc/security/limits.conf
fi
cp -a k3s-killall.sh /usr/bin
cp -a ../bin/* /usr/bin
for cmd in kubectl crictl ctr; do
    if [ ! -e /usr/bin/${cmd} ] ; then
        which_cmd=$(command -v ${cmd} 2>/dev/null || true)
        if [ -z "${which_cmd}" ]; then
            logger "Creating /usr/bin/${cmd} symlink to k3s"
            ln -sf /usr/bin/k3s /usr/bin/${cmd}
        else
            logger "Skipping /usr/bin/${cmd} symlink to k3s, command exists in PATH at ${which_cmd}"
        fi
    else
        logger "Skipping /usr/bin/${cmd} symlink to k3s, already exists"
    fi
done
for bin in /var/lib/rancher/k3s/data/**/bin/; do
    [ -d $bin ] && export PATH=$PATH:$bin:$bin/aux
done
#need after cri-shim
mkdir -p /etc/systemd/system
mkdir -p /etc/rancher/k3s/config.yaml.d
cp ../etc/k3s-sealos.yaml /etc/rancher/k3s/config.yaml.d/
cp ../etc/k3s.service /etc/systemd/system/
logger "init k3s success"
