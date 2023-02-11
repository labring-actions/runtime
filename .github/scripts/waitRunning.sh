#!/bin/bash

set -e

readonly C_TIMEOUT=${1:-1}
readonly R_TIMEOUT=${2:-5}

echo "CheckCreating(timeout=$C_TIMEOUT), CheckRunning(timeout=$R_TIMEOUT)"

function checker() {
  # for Creating
  kubectl get pods -oname --all-namespaces | sort >"all.$HOSTNAME.pods"
  until ! diff <(kubectl get pods -oname --all-namespaces | sort) "all.$HOSTNAME.pods" &>/dev/null; do
    sleep 3
    # timeout
    if ! find . -type f -name "all.$HOSTNAME.pods" -mmin -"$C_TIMEOUT" | grep "all.$HOSTNAME.pods" &>/dev/null; then exit 8; fi
  done
  # for Running
  until ! kubectl get pods --no-headers --all-namespaces | grep -vE Running &>/dev/null; do
    sleep 9
    if kubectl get pods --no-headers --all-namespaces | grep -vE Running; then
      echo
    fi
    # timeout
    if ! find . -type f -name "all.$HOSTNAME.pods" -mmin -"$R_TIMEOUT" | grep "all.$HOSTNAME.pods" &>/dev/null; then exit 88; fi
  done
  rm -f "all.$HOSTNAME.pods"
}

if kubectl version; then
  kubectl get pods -owide --all-namespaces
  kubectl get node -owide
  checker
  kubectl get pods -owide --all-namespaces
  kubectl get node -owide
fi
