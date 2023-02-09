#!/bin/bash

set -e

readonly ERR_CODE=127

case $(arch) in
x86_64)
  ARCH=amd64
  ;;
*)
  echo "sealosPatch(ghcr.io/labring/sealos:dev) only support amd64(x86_64)"
  exit $ERR_CODE
  ;;
esac

readonly IMAGE_CACHE_NAME="ghcr.io/labring-actions/cache"
readonly SEALOS=${sealoslatest:-$(
  until curl -sL "https://api.github.com/repos/labring/sealos/releases/latest" | grep tarball_url; do sleep 3; done | awk -F\" '{print $(NF-1)}' | awk -F/ '{print $NF}' | cut -dv -f2
)}

if [[ -z "$sealosPatch" ]]; then
  sudo docker run --rm -v "/usr/bin:/pwd" --entrypoint /bin/sh "$IMAGE_CACHE_NAME:sealos-v$SEALOS-$ARCH" -c "cp -a /sealos/sealos /pwd"
else
  sudo docker run --rm -v "/usr/bin:/pwd" --entrypoint /bin/sh ghcr.io/labring/sealos:dev -c "cp -a /usr/bin/sealos /pwd"
fi
echo
sudo sealos version
echo

until sudo docker run --rm -v "/usr/bin:/pwd" -w /tools --entrypoint /bin/sh "$IMAGE_CACHE_NAME:tools-$ARCH" -c "ls -lh && cp -a . /pwd"; do
  sleep 3
done
