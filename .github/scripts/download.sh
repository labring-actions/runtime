#!/bin/bash

set -e

until sudo docker run --rm -v "/usr/bin:/pwd" -w /tools --entrypoint /bin/sh "ghcr.io/labring-actions/cache:tools-amd64" -c "ls -lh && cp -a . /pwd"; do
  sleep 3
done
