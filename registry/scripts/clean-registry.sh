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
readonly BIN_DIR=${BIN_DIR:-/usr/bin}
# prepare registry storage as directory
cd "$(dirname "$0")" || error "error for $0"

readonly DATA=${1:-/var/lib/registry}
readonly CONFIG=${2:-/etc/registry}

check_service stop registry
rm -f /etc/systemd/system/registry.service
rm -f ${BIN_DIR}/registry

rm -rf "$DATA"
rm -rf "$CONFIG"
rm -f /etc/registry.yml

logger "clean registry success"
