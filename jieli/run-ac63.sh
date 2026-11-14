#!/usr/bin/env bash
#
# Run the AC63 SDK image. The SDK lives inside the image at /opt/ac63-sdk.
#
#   ./run-ac63.sh                              # interactive shell
#   ./run-ac63.sh make ac632n_spp_and_le       # build the SDK
#   MOUNTS="-v $PWD/out:/out" ./run-ac63.sh    # extra docker mounts
set -euo pipefail

IMAGE="${IMAGE:-enix223/jieli-ac63-sdk:1.0.0}"

# MOUNTS is intentionally word-split so it can carry several -v arguments.
# shellcheck disable=SC2086
exec docker run --rm -it \
    --platform linux/amd64 \
    ${MOUNTS:-} \
    -e HOME=/home/dev \
    "${IMAGE}" \
    "$@"
