#!/bin/bash

set -eu

readonly ERR_CODE=127

readonly CRI_TYPE=${criType?}
readonly KUBE_TYPE=${kubeType:-k8s}

readonly IMAGE_HUB_REGISTRY=${registry?}
readonly IMAGE_HUB_REPO=${repo?}
readonly IMAGE_HUB_USERNAME=${username?}
readonly IMAGE_HUB_PASSWORD=${password?}
readonly IMAGE_CACHE_NAME="ghcr.io/labring-actions/cache"

readonly IMAGE_TAG=${version?}
readonly KUBE="${IMAGE_TAG%%-*}"
if [[ "$sealoslatest" == latest ]]; then
  export sealosPatch="ghcr.io/labring/sealos-patch:latest"
  sealoslatest=$(until curl -sL "https://api.github.com/repos/labring/sealos/releases/latest" | grep tarball_url; do sleep 3; done | awk -F\" '{print $(NF-1)}' | awk -F/ '{print $NF}' | cut -dv -f2)
fi
readonly sealoslatest="${sealoslatest:-IMAGE_TAG#*-}"
readonly SEALOS=${sealoslatest?}
readonly SEALOS_XYZ="${SEALOS%%-*}"
if [[ "${SEALOS_XYZ//./}" -le 433 ]] && [[ $KUBE_TYPE == k3s ]] && [[ -z "$sealosPatch" ]]; then
  echo "INFO::skip $KUBE(build for k3s) when $SEALOS(sealos<=4.3.3)"
  exit
fi
readonly kube_major="${KUBE%.*}"
readonly sealos_major="${SEALOS%%-*}"
if [[ "${kube_major//./}" -ge 126 ]]; then
  if ! [[ "${sealos_major//./}" -le 413 ]] || [[ -n "$sealosPatch" ]]; then
    echo "Verifying the availability of unstable"
  else
    echo "INFO::skip kube(>=1.26) building when sealos <= 4.1.3"
    exit
  fi
  FROM_CRI=$(sudo buildah from "$IMAGE_CACHE_NAME:cri-amd64")
  MOUNT_CRI=$(sudo buildah mount "$FROM_CRI")
  case $CRI_TYPE in
  containerd)
    if ! [[ "$(sudo cat "$MOUNT_CRI"/cri/.versions | grep CONTAINERD | awk -F= '{print $NF}')" =~ v1\.([6-9]|[0-9][0-9])\.[0-9]+ ]]; then
      echo https://kubernetes.io/blog/2022/11/18/upcoming-changes-in-kubernetes-1-26/#cri-api-removal
      exit
    fi
    ;;
  docker)
    if ! [[ "$(sudo cat "$MOUNT_CRI"/cri/.versions | grep CRIDOCKER | awk -F= '{print $NF}')" =~ v0\.[3-9]\.[0-9]+ ]]; then
      echo https://github.com/Mirantis/cri-dockerd/issues/125
      exit
    fi
    ;;
  esac
fi

case $CRI_TYPE in
containerd)
  IMAGE_KUBE=kubernetes
  ;;
cri-o)
  IMAGE_KUBE=kubernetes-crio
  ;;
docker)
  IMAGE_KUBE=kubernetes-docker
  ;;
esac
if grep k3s <<<"$KUBE"; then
  IMAGE_KUBE=k3s
fi

if ! [[ "$SEALOS" =~ ^[0-9\.]+[0-9]$ ]] || [[ -n "$sealosPatch" ]]; then
  IMAGE_TAGS="v${KUBE%.*}-amd64,v${KUBE%.*}-arm64"
  IMAGE_PUSH_NAME=(
    "$IMAGE_HUB_REGISTRY/$IMAGE_HUB_REPO/$IMAGE_KUBE:v${KUBE%.*}-latest"
  )
else
  IMAGE_TAGS="v${KUBE%+*}-$SEALOS-amd64,v${KUBE%+*}-$SEALOS-arm64"
  if [[ "$SEALOS" == "$(
    until curl -sL "https://api.github.com/repos/labring/sealos/releases/latest"; do sleep 3; done | grep tarball_url | awk -F\" '{print $(NF-1)}' | awk -F/ '{print $NF}' | cut -dv -f2
  )" ]]; then
    IMAGE_PUSH_NAME=(
      "$IMAGE_HUB_REGISTRY/$IMAGE_HUB_REPO/$IMAGE_KUBE:v${KUBE%+*}"
      "$IMAGE_HUB_REGISTRY/$IMAGE_HUB_REPO/$IMAGE_KUBE:v${KUBE%+*}-$SEALOS"
    )
  else
    IMAGE_PUSH_NAME=(
      "$IMAGE_HUB_REGISTRY/$IMAGE_HUB_REPO/$IMAGE_KUBE:v${KUBE%+*}-$SEALOS"
    )
  fi
fi

sudo buildah login -u "$IMAGE_HUB_USERNAME" -p "$IMAGE_HUB_PASSWORD" "$IMAGE_HUB_REGISTRY"
for IMAGE_NAME in "${IMAGE_PUSH_NAME[@]}"; do
  echo "$IMAGE_TAGS" | sed "s~,~\n~g" | while read -r tag; do
    echo "${IMAGE_NAME%:*}:$tag"
  done | xargs sudo buildah manifest create --all "mf:${KUBE%+*}-$SEALOS" || exit $ERR_CODE
  if [[ $(sudo buildah inspect "mf:${KUBE%+*}-$SEALOS" | yq .manifests[].platform.architecture | uniq | grep 64 -c) -eq 2 ]]; then
    sudo buildah manifest push --rm --all "mf:${KUBE%+*}-$SEALOS" "docker://$IMAGE_NAME" && echo "$IMAGE_NAME push success"
  else
    sudo buildah manifest inspect "mf:${KUBE%+*}-$SEALOS" | yq -CP
    echo "ERROR::TARGETARCH for sealos build"
    sudo buildah images
    exit $ERR_CODE
  fi
done

sudo buildah images
