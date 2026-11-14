#!/usr/bin/env bash
#
# Run the JieLi SDK build image with ~/source (or SDK_ROOT) mounted at /sdk.
#
#   ./run.sh                                  # interactive shell in /sdk
#   ./run.sh bash -lc 'cd ac63-sdk && make ac632n_spp_and_le'
#   ./run.sh make -C /sdk/ac791-sdk ac791n_demo_demo_hello
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

# Default to the parent directory because this repo usually lives in
# ~/source/jieli-docker next to the SDK checkouts.
SDK_ROOT="${SDK_ROOT:-$(cd "${here}/.." && pwd)}"
IMAGE="${IMAGE:-enix223/jieli-build:1.0.0}"

exec docker run --rm -it \
    --platform linux/amd64 \
    -v "${SDK_ROOT}:/sdk" \
    -w /sdk \
    -e HOME=/home/dev \
    "${IMAGE}" \
    "$@"
