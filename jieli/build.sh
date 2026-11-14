#!/usr/bin/env bash
#
# Build the JieLi SDK build image. Passes the host UID/GID so the container user
# can write build artifacts into the bind-mounted SDK tree without root.
set -euo pipefail

cd "$(dirname "$0")"

IMAGE="${IMAGE:-enix223/jieli-build:1.0.0}"
TOOLCHAIN_URL="${TOOLCHAIN_URL:-https://pkgman.jieliapp.com/s/linux-toolchain}"
POSTBUILD_URL="${POSTBUILD_URL:-https://pkgman.jieliapp.com/s/linux-postbuild}"

docker build \
    --platform linux/amd64 \
    --build-arg "USER_ID=$(id -u)" \
    --build-arg "GROUP_ID=$(id -g)" \
    --build-arg "TOOLCHAIN_URL=${TOOLCHAIN_URL}" \
    --build-arg "POSTBUILD_URL=${POSTBUILD_URL}" \
    -t "${IMAGE}" \
    "$@" \
    .

echo
echo "Image built: ${IMAGE}"
echo "Start a shell with:  ./run.sh"
