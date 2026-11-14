# docker-embedded-device

Reproducible Docker build environments for embedded device SDKs, so the vendor
toolchain never has to be installed on the host.

The repository currently contains JieLi (Jieli Tech) SDK images under
[`jieli/`](jieli/):

| Image | Contents | Disk usage |
| --- | --- | --- |
| `enix223/jieli-build:1.0.0` | Ubuntu 22.04 + JieLi Linux toolchain (pi32v2 clang) + Linux post-build tools | ~0.9 GB |
| `enix223/jieli-ac63-sdk:1.0.0` | `jieli-build` + AC63 BT SDK, patched for Linux builds | ~4.5 GB |
| `enix223/jieli-ac791-sdk:1.0.0` | `jieli-build` + AC79 AIoT SDK, upstream unpatched | ~4.3 GB |
| `enix223/jieli-ac792-sdk:1.0.0` | `jieli-build` + AC792N SDK, upstream unpatched | ~4.8 GB |

All images are `linux/amd64` only: the toolchain binaries are x86-64 Linux ELF
executables. Docker can emulate them on ARM hosts, but builds will be slow.

## Layout

```
.
├── deploy.sh               # build and push the images to GHCR
└── jieli/
    ├── Dockerfile              # base image: toolchain + post-build tools
    ├── Dockerfile.ac63         # AC63 SDK image
    ├── Dockerfile.ac791        # AC791 SDK image
    ├── Dockerfile.ac792        # AC792 SDK image
    ├── build.sh                # builds the base image
    ├── build-ac63.sh           # builds the AC63 image
    ├── build-ac791.sh          # builds the AC791 image
    ├── build-ac792.sh          # builds the AC792 image
    ├── run.sh                  # base image with a host SDK mounted at /sdk
    ├── run-ac63.sh             # AC63 image shell
    ├── run-ac791.sh            # AC791 image shell
    ├── run-ac792.sh            # AC792 image shell
    ├── patches/ac63-linux-build/   # Linux build fixes applied to the AC63 SDK
    └── scripts/                # entrypoint + stand-ins for Jieli IDE helpers
```

## Requirements

- Docker Engine with BuildKit enabled (the Dockerfiles use the
  `docker/dockerfile:1` syntax and `--platform linux/amd64`)
- About 20 GB of free disk space for the images and build cache
- Network access to:
  - `pkgman.jieliapp.com` — JieLi Linux toolchain and post-build tools
  - `gitee.com` — SDK sources (cloned during the image build)

## Build

Build the base image first; all SDK images use it as their `FROM`:

```bash
cd jieli
./build.sh          # enix223/jieli-build:1.0.0

./build-ac63.sh     # enix223/jieli-ac63-sdk:1.0.0
./build-ac791.sh    # enix223/jieli-ac791-sdk:1.0.0
./build-ac792.sh    # enix223/jieli-ac792-sdk:1.0.0
```

Each SDK image shallow-clones the SDK from Gitee at build time, so rebuilding
the image is how you update the SDK. The build scripts accept environment
variables:

| Variable | Used by | Default |
| --- | --- | --- |
| `IMAGE` | all build scripts | tag shown in the table above |
| `BASE_IMAGE` | `build-ac63.sh`, `build-ac791.sh`, `build-ac792.sh` | `enix223/jieli-build:1.0.0` |
| `SDK_REPO` | SDK build scripts | the corresponding Gitee HTTPS URL |
| `SDK_BRANCH` | SDK build scripts | `master` (AC63), `release/AC79NN_SDK_V1.2.0` (AC791), `release/AC792N_SDK_V3` (AC792) |
| `TOOLCHAIN_URL`, `POSTBUILD_URL` | `build.sh` | JieLi package server URLs |

Examples:

```bash
# Build a specific SDK release
SDK_BRANCH=release/AC79NN_SDK_V1.1.0 ./build-ac791.sh
SDK_BRANCH=release/AC792N_SDK_V2   ./build-ac792.sh

# Build with a custom tag
IMAGE=myuser/jieli-ac791-sdk:dev ./build-ac791.sh
```

Extra arguments are passed through to `docker build`, e.g.
`./build-ac791.sh --no-cache`.

### SDK build notes

- **AC63** — the image applies the patches in
  `patches/ac63-linux-build/`, which rework the post-build download flow and
  make the SDK build on Linux without Jieli's IDE.
- **AC791 / AC792** — the images are based on the unpatched upstream SDK. The
  upstream Linux Makefile flow compiles and links `sdk.elf`, but its generated
  post-build script expects to run inside `cpu/<chip>/tools` (and AC792 also
  needs a `ROOT` variable the Makefile never defines). The images supply a
  small `/opt/utils/jl-post-build` shim, wired up through `MAKEFLAGS`, that
  handles this without modifying the SDK sources. `make` therefore succeeds,
  but produces `sdk.elf` and report files, not a flashable image
  (`app.bin` / `jl_isd.fw`). For flashing, use the SDK's `download_linux.c`
  flow or Jieli's IDE.

## Run

The SDK images have the SDK baked in: `/opt/ac63-sdk` for AC63,
`/opt/ac791-sdk` for AC791, and `/opt/ac792-sdk/sdk` for AC792 (that repository
keeps the buildable tree in its `sdk/` subdirectory). The run scripts start in
the correct directory:

```bash
cd jieli

./run-ac63.sh                                  # interactive shell
./run-ac63.sh make ac632n_spp_and_le

./run-ac791.sh
./run-ac791.sh make ac791n_demo_demo_hello
./run-ac791.sh make ac791n_wifi_camera -j$(nproc)

./run-ac792.sh
./run-ac792.sh make ac792n_demo_demo_hello
```

The run scripts accept `MOUNTS` for extra bind mounts:

```bash
MOUNTS="-v $PWD/out:/out" ./run-ac791.sh
```

The base image has no SDK baked in; mount one at `/sdk`:

```bash
SDK_ROOT=$HOME/source ./run.sh                       # ~/source mounted at /sdk
SDK_ROOT=$HOME/source ./run.sh make -C /sdk/ac791-sdk ac791n_demo_demo_hello
```

## Pushing the images to GHCR

The images can be published to the GitHub Container Registry as
`ghcr.io/enix223/<name>:<tag>`.

The root-level [`deploy.sh`](deploy.sh) automates the build-and-push flow:

```bash
./deploy.sh                 # build and push everything, base first
./deploy.sh ac791           # one target only
./deploy.sh --push-only     # push existing local images, no rebuild
TAG=2.0.0 ./deploy.sh       # custom tag
./deploy.sh --help
```

When you add a new SDK, add one line to the `IMAGES` table at the top of
`deploy.sh` (plus its `jieli/build-*.sh` script). The steps below are the
manual equivalent.

### 1. Authenticate

Create a GitHub personal access token (classic) with `write:packages`
(and `read:packages` if you also want to pull private images; add
`delete:packages` if you need to delete versions). A fine-grained token works
too if it grants Packages read/write. Then log in — GitHub passwords do not
work for the registry:

```bash
export CR_PAT=ghp_xxxxxxxxxxxxxxxxxxxx
echo "$CR_PAT" | docker login ghcr.io -u enix223 --password-stdin
```

### 2. Build directly for GHCR (recommended)

Tagging the images at build time avoids maintaining two sets of local tags.
Push the base image first; the SDK images reference it through `BASE_IMAGE`.

```bash
cd jieli
GHCR=ghcr.io/enix223

IMAGE=${GHCR}/jieli-build:1.0.0 ./build.sh
docker push ${GHCR}/jieli-build:1.0.0

BASE_IMAGE=${GHCR}/jieli-build:1.0.0 \
IMAGE=${GHCR}/jieli-ac791-sdk:1.0.0 ./build-ac791.sh
docker push ${GHCR}/jieli-ac791-sdk:1.0.0

# Same pattern for AC63 and AC792:
BASE_IMAGE=${GHCR}/jieli-build:1.0.0 \
IMAGE=${GHCR}/jieli-ac63-sdk:1.0.0 ./build-ac63.sh
docker push ${GHCR}/jieli-ac63-sdk:1.0.0

BASE_IMAGE=${GHCR}/jieli-build:1.0.0 \
IMAGE=${GHCR}/jieli-ac792-sdk:1.0.0 ./build-ac792.sh
docker push ${GHCR}/jieli-ac792-sdk:1.0.0
```

### 3. Or re-tag existing local images

If the images are already built with their default names:

```bash
GHCR=ghcr.io/enix223

for name in jieli-build jieli-ac63-sdk jieli-ac791-sdk jieli-ac792-sdk; do
    docker tag "enix223/${name}:1.0.0" "${GHCR}/${name}:1.0.0"
    docker push "${GHCR}/${name}:1.0.0"
done
```

Pushing an SDK image uploads all of its layers, including the base image's,
so consumers can `docker pull` it without pulling the base separately. The
base is pushed too so that other builds can use it as `FROM`.

The registry name must be lower-case. `enix223` already is; keep that in mind
if you change the namespace.

### 4. Package visibility

The first push creates a private package by default. To make it public, open
your GitHub profile → **Packages** → select the package → **Package settings**
→ **Change visibility** → **Public**. With the `gh` CLI:

```bash
gh api --method PATCH /user/packages/container/jieli-ac791-sdk \
    -f visibility=public
```

Optionally link each package to this repository so it appears under the repo's
Packages tab and inherits its permissions. Add the standard source label when
building (the build scripts pass extra arguments to `docker build`):

```bash
./build-ac791.sh \
    --label org.opencontainers.image.source=https://github.com/enix223/docker-embedded-device
```

### 5. Pull and use

```bash
docker pull ghcr.io/enix223/jieli-ac791-sdk:1.0.0

IMAGE=ghcr.io/enix223/jieli-ac791-sdk:1.0.0 \
    ./run-ac791.sh make ac791n_demo_demo_hello
```

On another machine, run `docker login ghcr.io` first if the package is
private.

### Automating in GitHub Actions

The workflow's built-in `GITHUB_TOKEN` can authenticate to GHCR if the job
requests package write permission:

```yaml
permissions:
  contents: read
  packages: write
```

Then log in with `docker/login-action@v3` (registry `ghcr.io`, username
`${{ github.actor }}`, password `${{ secrets.GITHUB_TOKEN }}`) and build/push
as above. The image builds clone from Gitee and contact
`pkgman.jieliapp.com`, so the runner needs outbound network access to both.
