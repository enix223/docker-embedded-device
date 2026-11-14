#!/usr/bin/env bash
#
# Build the AC792 SDK image (toolchain + pre-installed upstream SDK) on top of
# jieli-build. The SDK is cloned unpatched from Gitee during the image build.
#
#   ./build-ac792.sh
#   SDK_BRANCH=release/AC792N_SDK_V2 ./build-ac792.sh
set -euo pipefail

cd "$(dirname "$0")"

IMAGE="${IMAGE:-enix223/jieli-ac792-sdk:1.0.0}"
BASE_IMAGE="${BASE_IMAGE:-enix223/jieli-build:1.0.0}"
SDK_REPO="${SDK_REPO:-https://gitee.com/Jieli-Tech/fw-AC792_SDK.git}"
SDK_BRANCH="${SDK_BRANCH:-release/AC792N_SDK_V3}"

docker build \
    --platform linux/amd64 \
    --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
    --build-arg "SDK_REPO=${SDK_REPO}" \
    --build-arg "SDK_BRANCH=${SDK_BRANCH}" \
    -f Dockerfile.ac792 \
    -t "${IMAGE}" \
    "$@" \
    .

echo
echo "Image built: ${IMAGE}"
echo "Start a shell with:  ./run-ac792.sh"
echo "Build the SDK with:  ./run-ac792.sh make ac792n_demo_demo_hello"
