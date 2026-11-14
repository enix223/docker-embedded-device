#!/usr/bin/env bash
#
# Build and push the images to GitHub Container Registry.
#
#   ./deploy.sh                         # build and push everything, base first
#   ./deploy.sh ac791                   # build and push only the AC791 image
#   ./deploy.sh base ac792              # one or more targets
#   ./deploy.sh --push-only             # push existing local images, no rebuild
#   ./deploy.sh --no-push               # build only
#   TAG=2.0.0 ./deploy.sh               # custom tag
#   GHCR_OWNER=myuser ./deploy.sh       # different GHCR namespace
#
# Log in first; GitHub passwords do not work for the registry:
#
#   echo "$CR_PAT" | docker login ghcr.io -u enix223 --password-stdin
#
# ADDING A NEW SDK
# ----------------
# 1. Add its build script under jieli/ (e.g. jieli/build-ac793.sh).
# 2. Add one line to IMAGES below: "<target>|<image name>|<build script>".
# Keep the base image entry first: SDK images are built with
# BASE_IMAGE=<registry>/<owner>/jieli-build:<tag>.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

REGISTRY="${REGISTRY:-ghcr.io}"
GHCR_OWNER="${GHCR_OWNER:-enix223}"
TAG="${TAG:-1.0.0}"
# The jieli/build-*.sh scripts tag images under this namespace by default.
# Used as a fallback when --push-only is given but the registry-tagged image
# is not in the local Docker daemon.
LOCAL_OWNER="${LOCAL_OWNER:-enix223}"

# target|image name|build script, relative to this file. Base image first.
IMAGES=(
    "base|jieli-build|jieli/build.sh"
    "ac63|jieli-ac63-sdk|jieli/build-ac63.sh"
    "ac791|jieli-ac791-sdk|jieli/build-ac791.sh"
    "ac792|jieli-ac792-sdk|jieli/build-ac792.sh"
)
BASE_NAME="jieli-build"

build=1
push=1
dry_run=0
targets=()

die() {
    echo "deploy: $*" >&2
    exit 1
}

run() {
    if [ "$dry_run" = 1 ]; then
        printf '+'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] [target ...]

Build and push the images to ${REGISTRY}/${GHCR_OWNER}/<image>:${TAG}.

Targets:
$(for entry in "${IMAGES[@]}"; do
      IFS='|' read -r t n _ <<<"$entry"
      printf '  %-8s %s\n' "$t" "$n"
  done)
  all      every target above (default)

Options:
  -t, --tag TAG        image tag (default: ${TAG})
  -o, --owner OWNER    GHCR owner/namespace (default: ${GHCR_OWNER})
      --registry HOST  registry host (default: ${REGISTRY})
      --push-only      do not rebuild; push existing local images
      --no-push        build only
  -n, --dry-run        print commands instead of running them
      --list           list targets and exit
  -h, --help           show this help

When an SDK target is deployed, its base image is expected at
${REGISTRY}/${GHCR_OWNER}/${BASE_NAME}:${TAG}. Deploying "all" builds the
base first, so this is automatic there.
EOF
}

list_targets() {
    for entry in "${IMAGES[@]}"; do
        IFS='|' read -r t n s <<<"$entry"
        printf '%-8s %-20s %s\n' "$t" "$n" "$s"
    done
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -t|--tag)
            [ "$#" -ge 2 ] || die "missing value for $1"
            TAG=$2; shift 2 ;;
        -o|--owner)
            [ "$#" -ge 2 ] || die "missing value for $1"
            GHCR_OWNER=$2; shift 2 ;;
        --registry)
            [ "$#" -ge 2 ] || die "missing value for $1"
            REGISTRY=$2; shift 2 ;;
        --push-only)
            build=0; shift ;;
        --no-push|--build-only)
            push=0; shift ;;
        -n|--dry-run)
            dry_run=1; shift ;;
        --list)
            list_targets; exit 0 ;;
        -h|--help)
            usage; exit 0 ;;
        --)
            shift
            while [ "$#" -gt 0 ]; do targets+=("$1"); shift; done ;;
        -*)
            die "unknown option: $1 (try --help)" ;;
        *)
            targets+=("$1"); shift ;;
    esac
done

[ "$build" = 1 ] || [ "$push" = 1 ] || die "nothing to do: --push-only and --no-push are set"

if [ "$dry_run" = 0 ]; then
    command -v docker >/dev/null 2>&1 || die "docker not found in PATH"
    docker info >/dev/null 2>&1 || die "cannot connect to the Docker daemon"
fi

# Resolve the requested targets. No target or "all" selects every image.
select_all=0
if [ "${#targets[@]}" -eq 0 ]; then
    select_all=1
else
    for t in "${targets[@]}"; do
        [ "$t" = all ] && select_all=1
    done

    for t in "${targets[@]}"; do
        [ "$t" = all ] && continue
        found=0
        for entry in "${IMAGES[@]}"; do
            IFS='|' read -r known _ _ <<<"$entry"
            [ "$t" = "$known" ] && found=1
        done
        [ "$found" = 1 ] || die "unknown target: $t (try --list)"
    done
fi

push_image() {
    local name="$1" ref="$2" fallback

    # Only relevant with --push-only: a real build produces the registry tag.
    if [ "$build" = 0 ] && ! docker image inspect "$ref" >/dev/null 2>&1; then
        fallback="${LOCAL_OWNER}/${name}:${TAG}"
        if docker image inspect "$fallback" >/dev/null 2>&1; then
            echo "==> Tagging ${fallback} as ${ref}"
            run docker tag "$fallback" "$ref"
        elif [ "$dry_run" = 1 ]; then
            echo "==> (dry run) ${ref} not found locally" >&2
        else
            die "no local image ${ref} or ${fallback}; build it first (or drop --push-only)"
        fi
    fi

    echo "==> Pushing ${ref}"
    if ! run docker push "$ref"; then
        echo "Push failed. Log in first:" >&2
        echo "  echo \"\$CR_PAT\" | docker login ${REGISTRY} -u ${GHCR_OWNER} --password-stdin" >&2
        exit 1
    fi
}

for entry in "${IMAGES[@]}"; do
    IFS='|' read -r target name script <<<"$entry"

    if [ "$select_all" = 0 ]; then
        wanted=0
        for t in "${targets[@]}"; do
            [ "$t" = "$target" ] && wanted=1
        done
        [ "$wanted" = 1 ] || continue
    fi

    ref="${REGISTRY}/${GHCR_OWNER}/${name}:${TAG}"
    base_ref="${REGISTRY}/${GHCR_OWNER}/${BASE_NAME}:${TAG}"

    if [ "$build" = 1 ]; then
        echo "==> Building ${ref}"
        if [ "$name" = "$BASE_NAME" ]; then
            run env IMAGE="$ref" bash "$here/$script"
        else
            run env IMAGE="$ref" BASE_IMAGE="$base_ref" bash "$here/$script"
        fi
    fi

    if [ "$push" = 1 ]; then
        push_image "$name" "$ref"
    fi
done

echo
if [ "$dry_run" = 1 ]; then
    echo "Dry run complete. No build or push was executed."
elif [ "$push" = 1 ]; then
    echo "Deployed to ${REGISTRY}/${GHCR_OWNER} (tag ${TAG})."
else
    echo "Built for ${REGISTRY}/${GHCR_OWNER} (tag ${TAG}); not pushed (--no-push)."
fi
