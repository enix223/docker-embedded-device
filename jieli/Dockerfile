# Build environment for JieLi AC63 / AC791 / AC792 SDKs.
#
# The SDK itself is NOT baked into the image. Mount it at /sdk when running:
#
#   docker run --rm -it -v ~/source:/sdk -w /sdk enix223/jieli-build:1.0.0
#
# The JieLi toolchain and the Linux post-build tools are downloaded from
# Jieli's package server at build time. They are not redistributed by this
# repository.
#
# The toolchain binaries are x86-64 Linux ELF executables, so the image (and
# the host running it) must be linux/amd64.
# syntax=docker/dockerfile:1

FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TOOLCHAIN_URL=https://pkgman.jieliapp.com/s/linux-toolchain
ARG POSTBUILD_URL=https://pkgman.jieliapp.com/s/linux-postbuild
# Match the host user so files created in the mounted SDK stay host-owned.
ARG USER_ID=1000
ARG GROUP_ID=1000

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# make/python3 are the only host build prerequisites; clang comes from the
# JieLi toolchain below. The X/GL libraries are runtime deps of ufw_maker and
# friends in the post-build tools archive.
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        xz-utils \
        make \
        file \
        git \
        python3 \
        unzip \
        zip \
        less \
        vim-tiny \
        libstdc++6 \
        zlib1g \
        libbz2-1.0 \
        libbrotli1 \
        libbsd0 \
        libmd0 \
        libexpat1 \
        libpng16-16 \
        libuuid1 \
        libgl1 \
        libegl1 \
        libgbm1 \
        libdrm2 \
        libx11-6 \
        libxcb1 \
        libxkbcommon0 \
        libfontconfig1 \
        libfreetype6 \
        libsm6 \
        libice6 \
    && rm -rf /var/lib/apt/lists/*

# JieLi Linux toolchain (clang targeting pi32v2, plus pi32/q32s variants).
# The archive top-level dir is versioned (jieli-linux-toolchains-YYYYMMDD.N),
# so flatten it into /opt/jieli. The pi32v2/bin/* tools are symlinks into
# ../common/bin, so the directory layout must be preserved.
RUN tmp="$(mktemp -d)" \
    && curl -fsSL "${TOOLCHAIN_URL}" -o "${tmp}/toolchain.tar.xz" \
    && tar -xJf "${tmp}/toolchain.tar.xz" -C "${tmp}" \
    && src="$(find "${tmp}" -mindepth 1 -maxdepth 1 -type d -print -quit)" \
    && mkdir -p /opt/jieli \
    && cp -a "${src}/." /opt/jieli/ \
    && rm -rf "${tmp}" \
    && test -e /opt/jieli/pi32v2/bin/clang \
    && test -f /opt/jieli/pi32v2/lib/r3/libc.a

# Linux post-build tools (isd_download, fw_add, ufw_maker, packres, ...).
# Kept in /opt/jieli/postbuild; also exposed on PATH.
RUN tmp="$(mktemp -d)" \
    && curl -fsSL "${POSTBUILD_URL}" -o "${tmp}/postbuild.tar.xz" \
    && mkdir -p /opt/jieli/postbuild \
    && tar -xJf "${tmp}/postbuild.tar.xz" -C /opt/jieli/postbuild --strip-components=1 \
    && rm -rf "${tmp}" \
    && chmod +x /opt/jieli/postbuild/* \
    && ln -sf packres /opt/jieli/postbuild/pack_res

# Stand-ins for tools normally shipped with Jieli's IDE. The SDK Makefiles
# invoke these during the post-build step on Linux; without them `make` fails
# even though compiling/linking succeeded. Copies live in scripts/.
COPY scripts/strip-ini scripts/report_segment_usage scripts/host-client /opt/utils/
COPY scripts/sudo /usr/local/bin/sudo
RUN chmod +x /opt/utils/strip-ini /opt/utils/report_segment_usage \
             /opt/utils/host-client /usr/local/bin/sudo

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Non-root user matching the host's UID/GID (passed by build.sh).
RUN groupadd --gid "${GROUP_ID}" dev \
    && useradd --uid "${USER_ID}" --gid "${GROUP_ID}" \
               --create-home --shell /bin/bash dev

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JIELI_TOOLCHAIN=/opt/jieli \
    PATH="/opt/jieli/pi32v2/bin:/opt/jieli/common/bin:/opt/utils:/opt/jieli/postbuild:${PATH}"

USER dev
WORKDIR /sdk

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
