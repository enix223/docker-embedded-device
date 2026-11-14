#!/usr/bin/env bash
#
# Build the AC63 SDK image (toolchain + pre-patched SDK) on top of jieli-build.
#
#   ./build-ac63.sh                       # clone Gitee master
#   SDK_BRANCH=ac63_bt_sdk_release_v2.4.0 ./build-ac63.sh
set -euo pipefail

cd "$(dirname "$0")"

IMAGE="${IMAGE:-enix223/jieli-ac63-sdk:1.0.0}"
BASE_IMAGE="${BASE_IMAGE:-enix223/jieli-build:1.0.0}"
SDK_REPO="${SDK_REPO:-https://gitee.com/Jieli-Tech/fw-AC63_BT_SDK.git}"
SDK_BRANCH="${SDK_BRANCH:-master}"

docker build \
    --platform linux/amd64 \
    --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
    --build-arg "SDK_REPO=${SDK_REPO}" \
    --build-arg "SDK_BRANCH=${SDK_BRANCH}" \
    -f Dockerfile.ac63 \
    -t "${IMAGE}" \
    "$@" \
    .

echo
echo "Image built: ${IMAGE}"
echo "Start a shell with:  ./run-ac63.sh"
echo "Build the SDK with:  ./run-ac63.sh make ac632n_spp_and_le"
