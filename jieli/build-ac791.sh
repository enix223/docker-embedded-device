#!/usr/bin/env bash
#
# Build the AC791 SDK image (toolchain + pre-installed upstream SDK) on top of
# jieli-build. The SDK is cloned unpatched from Gitee during the image build.
#
#   ./build-ac791.sh
#   SDK_BRANCH=release/AC79NN_SDK_V1.1.0 ./build-ac791.sh
set -euo pipefail

cd "$(dirname "$0")"

IMAGE="${IMAGE:-enix223/jieli-ac791-sdk:1.0.0}"
BASE_IMAGE="${BASE_IMAGE:-enix223/jieli-build:1.0.0}"
SDK_REPO="${SDK_REPO:-https://gitee.com/Jieli-Tech/fw-AC79_AIoT_SDK.git}"
SDK_BRANCH="${SDK_BRANCH:-release/AC79NN_SDK_V1.2.0}"

docker build \
    --platform linux/amd64 \
    --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
    --build-arg "SDK_REPO=${SDK_REPO}" \
    --build-arg "SDK_BRANCH=${SDK_BRANCH}" \
    -f Dockerfile.ac791 \
    -t "${IMAGE}" \
    "$@" \
    .

echo
echo "Image built: ${IMAGE}"
echo "Start a shell with:  ./run-ac791.sh"
echo "Build the SDK with:  ./run-ac791.sh make ac791n_demo_demo_hello"
