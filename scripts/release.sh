#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

: "${IMAGE_REPO:?Set IMAGE_REPO in .env, e.g. imbtechdev/imb_hr}"
: "${VERSION:?Set VERSION, e.g. make release VERSION=1.0.0}"
platforms="${IMAGE_PLATFORMS:-linux/amd64,linux/arm64}"
targets="${TARGETS:-backend frontend dumper}"

docker buildx inspect miller-builder >/dev/null 2>&1 \
  || docker buildx create --name miller-builder --driver docker-container >/dev/null

build() {
  local name="$1"; shift
  local tag="${IMAGE_REPO}:miller-${name}-${VERSION}"
  echo "==> ${tag} (${platforms})"
  docker buildx build --builder miller-builder --platform "${platforms}" \
    -t "${tag}" -t "${IMAGE_REPO}:miller-${name}-latest" \
    --label "org.opencontainers.image.version=${VERSION}" \
    --push "$@"
}

for target in ${targets}; do
  case "${target}" in
    backend)
      build backend --label "org.opencontainers.image.revision=$(git -C src/backend rev-parse HEAD)" \
        -f docker/backend/Dockerfile.prod --build-context docker=docker/backend src/backend ;;
    frontend)
      build frontend --label "org.opencontainers.image.revision=$(git -C src/frontend rev-parse HEAD)" \
        -f docker/frontend/Dockerfile.prod --build-context nginx=docker/frontend src/frontend ;;
    dumper)
      build dumper docker/dumper ;;
    *)
      echo "Unknown target: ${target}" >&2; exit 1 ;;
  esac
done
