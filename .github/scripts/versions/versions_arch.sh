#!/bin/bash

set -e

readonly CRI_TYPE=${criType?}
readonly KUBE_TYPE=${kubeType:-k8s}

readonly IMAGE_HUB_REGISTRY=${registry:-}
readonly IMAGE_HUB_REPO=${repo?}
if [[ "$sealoslatest" == latest ]]; then
  export sealosPatch="ghcr.io/labring/sealos-patch:latest"
  sealoslatest=$(until curl -sL "https://api.github.com/repos/labring/sealos/releases/latest" | grep tarball_url; do sleep 3; done | awk -F\" '{print $(NF-1)}' | awk -F/ '{print $NF}' | cut -dv -f2)
fi
readonly SEALOS=${sealoslatest?}
readonly SEALOS_XYZ="${SEALOS%%-*}"

case $CRI_TYPE in
containerd)
  IMAGE_KUBE=kubernetes
  ;;
docker)
  IMAGE_KUBE=kubernetes-docker
  ;;
cri-o)
  IMAGE_KUBE=kubernetes-crio
  ;;
esac
if grep k3s <<<"$KUBE"; then
  IMAGE_KUBE=k3s
fi

# Recursively finds all directories with a go.mod file and creates
# a GitHub Actions JSON output option. This is used by the linter action.
echo "Resolving versions in $(pwd)"
rm -rf .versions
mkdir -p .versions
for file in $(pwd)/.github/versions/${part:-*}/CHANGELOG*; do
  K8S_MD=${file##*/}
  case $CRI_TYPE in
  containerd | docker)
    case $K8S_MD in
    CHANGELOG-1.1[0-5].md)
      continue
      ;;
    esac
    ;;
  cri-o)
    case $K8S_MD in
    CHANGELOG-1.1[0-9].md)
      continue
      ;;
    esac
    ;;
  esac
  while IFS= read vKUBE; do
    if [[ "$allBuild" == true ]]; then
      echo "$vKUBE" >>".versions/$K8S_MD"
    else
      case $IMAGE_HUB_REGISTRY in
      docker.io | ghcr.io)
        if until curl -sL "https://hub.docker.com/v2/repositories/$IMAGE_HUB_REPO/$IMAGE_KUBE/tags/$vKUBE-$SEALOS"; do sleep 3; done |
          grep digest >/dev/null; then
          echo "$IMAGE_HUB_REGISTRY/$IMAGE_HUB_REPO/$IMAGE_KUBE:$vKUBE-$SEALOS already existed"
        else
          echo "$vKUBE" >>".versions/$K8S_MD"
        fi
        ;;
      *)
        echo "$vKUBE" >>".versions/$K8S_MD"
        ;;
      esac
    fi
  done < <(
    until curl -sL "https://github.com/kubernetes/kubernetes/raw/master/CHANGELOG/$K8S_MD"; do sleep 3; done |
      grep -E '^- \[v[0-9\.]+\]' | awk '{print $2}' | awk -F\[ '{print $2}' | awk -F\] '{print $1}' >".versions/$K8S_MD.cached"
    head -n 1 ".versions/$K8S_MD.cached" >".versions/$K8S_MD.latest"
    case $KUBE_TYPE in
    k3s)
      git ls-remote --refs --sort="-version:refname" --tags "https://github.com/k3s-io/k3s.git" | cut -d/ -f3- | grep -E "^$(cut -d. -f-2 ".versions/$K8S_MD.latest").[0-9]+\+k3s[0-9]$" | head -n 1 >".versions/$K8S_MD.cached"
      cp ".versions/$K8S_MD.cached" ".versions/$K8S_MD.latest"
      ;;
    esac
    cat ".versions/$K8S_MD.cached"
  )
  [[ -s ".versions/$K8S_MD" ]] || cp ".versions/$K8S_MD.latest" ".versions/$K8S_MD"
  if [[ -z "$(cat ".versions/$K8S_MD")" ]]; then
    mv ".versions/$K8S_MD.latest" ".versions/$K8S_MD"
  fi
  if ! [[ "$SEALOS" =~ ^[0-9\.]+[0-9]$ ]] || [[ -n "$sealosPatch" ]] || [[ "${SEALOS_XYZ//./}" -ge 416 ]]; then
    {
      cut -dv -f 2 ".versions/$K8S_MD" | head -n 1
      cut -dv -f 2 ".versions/$K8S_MD" | tail -n 1
    } | sort | uniq | awk '{printf "{\"'version'\":\"%s\",\"'arch'\":\"amd64\"},{\"'version'\":\"%s\",\"'arch'\":\"arm64\"},",$1,$1}' >>.versions/versions_arch.txt
  else
    cut -dv -f 2 ".versions/$K8S_MD" |
      awk '{printf "{\"'version'\":\"%s\",\"'arch'\":\"amd64\"},{\"'version'\":\"%s\",\"'arch'\":\"arm64\"},",$1,$1}' >>.versions/versions_arch.txt
  fi
done
SET_MATRIX=$(cat .versions/versions_arch.txt)
echo "{\"include\":[${SET_MATRIX%?}]}" | yq -P
echo "matrix={\"include\":[${SET_MATRIX%?}]}" >>$GITHUB_OUTPUT
