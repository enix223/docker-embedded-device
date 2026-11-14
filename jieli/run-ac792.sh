#!/usr/bin/env bash
#
# Run the AC792 SDK image. The SDK lives inside the image at /opt/ac792-sdk,
# with the buildable tree under /opt/ac792-sdk/sdk.
#
#   ./run-ac792.sh                              # interactive shell
#   ./run-ac792.sh make ac792n_demo_demo_hello  # build the SDK
#   MOUNTS="-v $PWD/out:/out" ./run-ac792.sh    # extra docker mounts
set -euo pipefail

IMAGE="${IMAGE:-enix223/jieli-ac792-sdk:1.0.0}"

# MOUNTS is intentionally word-split so it can carry several -v arguments.
# shellcheck disable=SC2086
exec docker run --rm -it \
    --platform linux/amd64 \
    ${MOUNTS:-} \
    -e HOME=/home/dev \
    "${IMAGE}" \
    "$@"
