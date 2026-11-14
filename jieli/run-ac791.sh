#!/usr/bin/env bash
#
# Run the AC791 SDK image. The SDK lives inside the image at /opt/ac791-sdk.
#
#   ./run-ac791.sh                              # interactive shell
#   ./run-ac791.sh make ac791n_demo_demo_hello  # build the SDK
#   MOUNTS="-v $PWD/out:/out" ./run-ac791.sh    # extra docker mounts
set -euo pipefail

IMAGE="${IMAGE:-enix223/jieli-ac791-sdk:1.0.0}"

# MOUNTS is intentionally word-split so it can carry several -v arguments.
# shellcheck disable=SC2086
exec docker run --rm -it \
    --platform linux/amd64 \
    ${MOUNTS:-} \
    -e HOME=/home/dev \
    "${IMAGE}" \
    "$@"
