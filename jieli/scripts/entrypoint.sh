#!/usr/bin/env bash
#
# Container entrypoint: configure the JieLi build environment, then run the
# requested command (defaults to an interactive bash in /sdk).
set -e

# The LTO linker opens a large number of archives at once. JieLi's README
# recommends > 8096 file descriptors; all three SDKs fail to link otherwise.
ulimit -n 65535 2>/dev/null || ulimit -n 8192 2>/dev/null || true

# Some post-build scripts call per-chip helpers by bare name (lz4_packet,
# objsizedump, ...). Add the mounted SDKs' tool dirs to PATH.
for d in /sdk/ac63-sdk/cpu/*/tools \
         /sdk/ac791-sdk/cpu/*/tools \
         /sdk/ac792-sdk/sdk/cpu/*/tools; do
    [ -d "$d" ] && PATH="${PATH}:${d}"
done

# The AC63 SDK ships lz4_packet as Linux ELF but without the executable bit.
# Put an executable copy in a writable dir instead of chmod'ing the mounted
# SDK (which would show up as a local modification in git).
if [ -d /sdk/ac63-sdk/cpu ]; then
    for f in /sdk/ac63-sdk/cpu/*/tools/lz4_packet; do
        if [ -f "$f" ]; then
            jlbin="${HOME}/.local/jl-bin"
            mkdir -p "$jlbin"
            cp -f "$f" "${jlbin}/lz4_packet"
            chmod +x "${jlbin}/lz4_packet"
            PATH="${jlbin}:${PATH}"
            break
        fi
    done
fi

export PATH

exec "$@"
