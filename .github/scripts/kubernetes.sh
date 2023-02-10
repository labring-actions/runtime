#!/bin/bash

set -eu

readonly ERR_CODE=127

readonly ARCH=${arch?}
readonly CRI_TYPE=${criType?}
readonly KUBE=${kubeVersion?}
readonly SEALOS=${sealoslatest?}

readonly KUBE_XY="${KUBE%.*}"
readonly SEALOS_XYZ="${SEALOS%%-*}"

readonly IMAGE_HUB_REGISTRY=${registry?}
readonly IMAGE_HUB_REPO=${repo?}
readonly IMAGE_HUB_USERNAME=${username?}
readonly IMAGE_HUB_PASSWORD=${password?}
readonly IMAGE_CACHE_NAME="ghcr.io/labring-actions/cache"

ROOT="/tmp/$(whoami)/build"
PATCH="/tmp/$(whoami)/patch"
sudo rm -rf "$ROOT" "$PATCH"
mkdir -p "$ROOT" "$PATCH"

cp -a "$CRI_TYPE"/* "$ROOT"
cp -a registry/* "$ROOT"
cp -a k8s/* "$ROOT"

pushd "$ROOT"
mkdir -p bin cri opt images/shim

MOUNT_CRI=$(sudo buildah mount "$(sudo buildah from "$IMAGE_CACHE_NAME:cri-$ARCH")")
# Check support for kube-v1.26+
if [[ "${KUBE_XY//./}" -ge 126 ]] && [[ "${SEALOS_XYZ//./}" -le 413 ]] && [[ -z "$sealosPatch" ]]; then
  echo "INFO::skip $KUBE(kube>=1.26) when $SEALOS(sealos<=4.1.3)"
  echo https://kubernetes.io/blog/2022/11/18/upcoming-changes-in-kubernetes-1-26/#cri-api-removal
  exit
fi

# image-cri-shim sealctl
if [[ -n "$sealosPatch" ]]; then
  rmdir "$PATCH"
  sudo cp -au "$(sudo buildah mount "$(sudo buildah from "$sealosPatch-$ARCH")")" "$PATCH"
  tree "$PATCH"
  sudo cp -au "$PATCH"/* .
else
  MOUNT_SEALOS=$(sudo buildah mount "$(sudo buildah from "$IMAGE_CACHE_NAME:sealos-v$SEALOS-$ARCH")")
  sudo cp -au "$MOUNT_SEALOS"/sealos/image-cri-shim cri/
  sudo cp -au "$MOUNT_SEALOS"/sealos/sealctl opt/
fi

# crictl helm kubeadm,kubectl,kubelet conntrack registry and cri(kubelet)
MOUNT_KUBE=$(sudo buildah mount "$(sudo buildah from "$IMAGE_CACHE_NAME:kubernetes-v$KUBE-$ARCH")")
MOUNT_CRIO=$(sudo buildah mount "$(sudo buildah from "$IMAGE_CACHE_NAME:cri-v$KUBE_XY-$ARCH")")
MOUNT_TOOLS=$(sudo buildah mount "$(sudo buildah from "$IMAGE_CACHE_NAME:tools-$ARCH")")
sudo tar -xzf "$MOUNT_CRIO"/cri/crictl.tar.gz -C bin/
sudo cp -au "$MOUNT_TOOLS"/tools/upx bin/
#sudo cp -au "$MOUNT_KUBE"/bin/{kubeadm,kubectl,kubelet} bin/
sudo cp -au "$MOUNT_CRI"/cri/conntrack bin/
sudo cp -au "$MOUNT_CRI"/cri/lsof opt/
sudo cp -au "$MOUNT_CRI"/cri/{registry,libseccomp.tar.gz} cri/
case $CRI_TYPE in
containerd)
  IMAGE_KUBE=kubernetes
  sudo cp -au "$MOUNT_CRI"/cri/cri-containerd.tar.gz cri/
  ;;
cri-o)
  IMAGE_KUBE=kubernetes-${CRI_TYPE//-/}
  sudo cp -au "$MOUNT_CRIO"/cri/cri-o.tar.gz cri/
  sudo cp -au "$MOUNT_CRIO"/cri/{install.crio,crio.files} cri/
  ;;
docker)
  IMAGE_KUBE=kubernetes-$CRI_TYPE
  if [[ "${KUBE_XY//./}" -ge 126 ]]; then
    sudo cp -au "$MOUNT_CRI"/cri/cri-dockerd.tgz cri/
  else
    sudo cp -au "$MOUNT_CRI"/cri/cri-dockerd.tgzv125 cri/cri-dockerd.tgz
  fi
  DOCKER_XY=$(until curl -sL "https://github.com/kubernetes/kubernetes/raw/release-$KUBE_XY/build/dependencies.yaml" | yq '.dependencies[]|select(.name == "docker")|.version'; do sleep 3; done)
  case $DOCKER_XY in
  18.09 | 19.03 | 20.10)
    sudo cp -au "$MOUNT_CRI/cri/docker-$DOCKER_XY.tgz" cri/docker.tgz
    ;;
  *)
    sudo cp -au "$MOUNT_CRI/cri/docker.tgz" cri/
    ;;
  esac
  ;;
esac

# define ImageTag for kube
if [[ "${SEALOS//./}" =~ ^[0-9]+$ ]] && [[ -z "$sealosPatch" ]]; then
  readonly RELEASE=stable
  if [[ "$SEALOS" == "$(
    until curl -sL "https://api.github.com/repos/labring/sealos/releases/latest"; do sleep 3; done | grep tarball_url | awk -F\" '{print $(NF-1)}' | awk -F/ '{print $NF}' | cut -dv -f2
  )" ]]; then
    IMAGE_PUSH_NAME=(
      "$IMAGE_HUB_REGISTRY/$IMAGE_HUB_REPO/$IMAGE_KUBE:v$KUBE-$ARCH"
      "$IMAGE_HUB_REGISTRY/$IMAGE_HUB_REPO/$IMAGE_KUBE:v$KUBE-$SEALOS-$ARCH"
    )
  else
    IMAGE_PUSH_NAME=(
      "$IMAGE_HUB_REGISTRY/$IMAGE_HUB_REPO/$IMAGE_KUBE:v$KUBE-$SEALOS-$ARCH"
    )
  fi
else
  readonly RELEASE=unstable
  IMAGE_PUSH_NAME=(
    "$IMAGE_HUB_REGISTRY/$IMAGE_HUB_REPO/$IMAGE_KUBE:v$KUBE_XY-$ARCH"
  )
fi

### Sealed ###
sudo chown -R "$(whoami)" "$ROOT"
### Sealed ###

# upx
if upx -d \
  cri/image-cri-shim opt/sealctl; then
  if [[ amd64 == "$ARCH" ]]; then
    cri/image-cri-shim --version
    opt/sealctl version
  fi
else
  ls -lh cri/image-cri-shim opt/sealctl
fi
if upx \
  cri/image-cri-shim opt/sealctl \
  bin/crictl cri/registry; then
  if [[ amd64 == "$ARCH" ]]; then
    cri/image-cri-shim --version
    opt/sealctl version
    cri/registry --version
  fi
else
  ls -lh cri/image-cri-shim opt/sealctl \
    bin/crictl cri/registry
fi

# define ImageTag for lvscare(ipvs)
if rmdir "$PATCH" 2>/dev/null; then
  ipvsImage="ghcr.io/labring/lvscare:v$SEALOS"
else
  ipvsImage="${sealosPatch%%/*}/labring/lvscare:$(find "registry" -type d | grep -E "tags/.+-$ARCH$" | awk -F/ '{print $NF}')"
  rm -fv images/shim/*vscare*
fi
echo "$ipvsImage" >images/shim/LvscareImageList

# update Kubefile
pauseImage=$(sudo grep /pause: "$MOUNT_KUBE/images/shim/DefaultImageList")
# shellcheck disable=SC2002
cat Kubefile |
  sed "s#__pause__#${pauseImage#*/}#g" |
  sed "s#__lvscare__#$ipvsImage#g" |
  sed "s/v0.0.0/v$KUBE/g" |
  sed -E "s#^FROM .+#FROM $IMAGE_CACHE_NAME:kubernetes-v$KUBE-$ARCH#" >"Kubefile.$(uname)"
mv -fv "Kubefile.$(uname)" Kubefile

#### building ###
IMAGE_BUILD="$IMAGE_HUB_REGISTRY/$IMAGE_HUB_REPO/$IMAGE_KUBE:build-$(date +%s)"
find . -type f -exec file {} \; | grep -E "(executable,|/ld-)" | awk -F: '{print $1}' | grep -vE "\.so" | while IFS='' read -r elf; do echo "${elf}"; done | xargs chmod a+x
tree -L 5
sudo sealos build -t "$IMAGE_BUILD" --platform "linux/$ARCH" .

# debug for sealos run with amd64
if [[ amd64 == "$ARCH" ]]; then
  if [[ unstable == "$RELEASE" ]]; then
    sudo rm -f /usr/bin/upx # for common.sh
    dpkg-query --search "$(command -v containerd)" "$(command -v docker)"
    sudo apt-get remove -y moby-buildx moby-cli moby-compose moby-containerd moby-engine &>/dev/null
    sudo systemctl unmask "${CRI_TYPE//-/}" || true
    sudo mkdir -p /sys/fs/cgroup/systemd
    sudo mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd || true
    if ! sudo sealos run "$IMAGE_BUILD" --single; then
      case $CRI_TYPE in
      containerd)
        "$CRI_TYPE" --version
        ;;
      cri-o)
        "$CRI_TYPE" --version
        ;;
      docker)
        "$CRI_TYPE" info
        ;;
      esac
      sudo crictl ps -a || true
      if [[ "${KUBE_XY//./}" -le 116 ]]; then
        export SEALOS_RUN="skipped::compatibility"
        echo "Incompatible versions $KUBE($CRI_TYPE) fail testing"
        echo "Incompatible versions $KUBE($CRI_TYPE) fail testing"
        echo "Incompatible versions $KUBE($CRI_TYPE) fail testing"
      else
        export SEALOS_RUN="failed"
        systemctl status "${CRI_TYPE//-/}" || true
        journalctl -xeu "${CRI_TYPE//-/}" || true
        systemctl status kubelet || true
        journalctl -xeu kubelet || true
      fi
    else
      export SEALOS_RUN="succeed::run"
      mkdir -p "$HOME/.kube"
      sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
      sudo chown "$(whoami)" "$HOME/.kube/config"
      kubectl get nodes --no-headers -oname | while read -r node; do kubectl get "$node" -o template='{{range .spec.taints}}{{.key}}{{"\n"}}{{end}}' | while read -r taint; do
        # shellcheck disable=SC2086
        kubectl taint ${node/\// } "$taint"-
      done; done
      until ! kubectl get pods --no-headers --all-namespaces | grep -vE Running; do
        sleep 5
        if kubectl get pods --no-headers --all-namespaces | grep -E "5m.+s"; then
          break
        fi
      done
      kubectl get pods -owide --all-namespaces
      kubectl get node -owide
    fi
    sudo sealos reset --force
  else
    export SEALOS_RUN="stable::build"
  fi
else
  export SEALOS_RUN="skipped::arm64"
fi

# Check images for local
{
  while IFS= read -r i; do
    j=${i%/_manifests*}
    image=${j##*/}
    while IFS= read -r tag; do echo "$image:$tag"; done < <(sudo ls "$i")
  done < <(sudo find registry -name tags -type d | grep _manifests/tags) | sort
}

echo "SEALOS_STATUS => $SEALOS_RUN"
echo "SEALOS_STATUS => $SEALOS_RUN"
echo "SEALOS_STATUS => $SEALOS_RUN"

# Check images for push
{
  if ! [[ "$SEALOS_RUN" =~ failed ]]; then
    echo -n "ImageArchitecture: "
    if sudo buildah inspect "$IMAGE_BUILD" | yq .OCIv1.architecture | grep "$ARCH" ||
      sudo buildah inspect "$IMAGE_BUILD" | yq .Docker.architecture | grep "$ARCH"; then
      echo -n >"/tmp/$IMAGE_HUB_REGISTRY.v$KUBE-$ARCH.images"
      # check images
      for IMAGE_NAME in "${IMAGE_PUSH_NAME[@]}"; do
        if [[ "$allBuild" != true ]]; then
          case $IMAGE_HUB_REGISTRY in
          docker.io)
            if until curl -sL "https://hub.docker.com/v2/repositories/$IMAGE_HUB_REPO/$IMAGE_KUBE/tags/${IMAGE_NAME##*:}"; do sleep 3; done |
              grep digest >/dev/null; then
              if ! grep "$KUBE" <<<"$${IMAGE_NAME##*:}" &>/dev/null; then
                # always push for kube 1.xx(DEV)
                echo "$IMAGE_NAME" >>"/tmp/$IMAGE_HUB_REGISTRY.v$KUBE-$ARCH.images"
              else
                echo "$IMAGE_NAME already existed"
              fi
            else
              echo "$IMAGE_NAME" >>"/tmp/$IMAGE_HUB_REGISTRY.v$KUBE-$ARCH.images"
            fi
            ;;
          *)
            echo "$IMAGE_NAME" >>"/tmp/$IMAGE_HUB_REGISTRY.v$KUBE-$ARCH.images"
            ;;
          esac
        else
          echo "$IMAGE_NAME" >>"/tmp/$IMAGE_HUB_REGISTRY.v$KUBE-$ARCH.images"
        fi
      done
      # push images
      if [[ -s "/tmp/$IMAGE_HUB_REGISTRY.v$KUBE-$ARCH.images" ]]; then
        sudo sealos login -u "$IMAGE_HUB_USERNAME" -p "$IMAGE_HUB_PASSWORD" "$IMAGE_HUB_REGISTRY"
        while read -r IMAGE_NAME; do
          sudo sealos tag "$IMAGE_BUILD" "$IMAGE_NAME"
          until sudo sealos push "$IMAGE_NAME"; do sleep 3; done
        done <"/tmp/$IMAGE_HUB_REGISTRY.v$KUBE-$ARCH.images"
        sudo sealos logout "$IMAGE_HUB_REGISTRY"
      fi
    else
      sudo buildah inspect "$IMAGE_BUILD" | yq -CP
      echo "ERROR::TARGETARCH for sealos build"
      exit $ERR_CODE
    fi
  fi
}

sudo buildah containers --format "{{.ContainerID}}({{.ContainerName}}) {{.ImageID}}({{.ImageName}})"
sudo buildah umount --all &>/dev/null
sudo buildah rm --all &>/dev/null
sudo buildah images

if [[ "$SEALOS_RUN" =~ failed ]]; then
  exit $ERR_CODE
fi
