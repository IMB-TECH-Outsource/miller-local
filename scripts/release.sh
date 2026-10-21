#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

: "${IMAGE_REPO:?Set IMAGE_REPO in .env, e.g. imbtechdev/imb_hr}"
: "${VERSION:?Set VERSION, e.g. make release VERSION=1.0.0}"
platforms="${IMAGE_PLATFORMS:-linux/amd64,linux/arm64}"
targets="${TARGETS:-backend frontend}"

docker buildx inspect miller-builder >/dev/null 2>&1 \
  || docker buildx create --name miller-builder --driver docker-container >/dev/null

build() {
  local name="$1"; shift
  local tag="${IMAGE_REPO}:miller-${name}-${VERSION}"
  echo "==> ${tag} (${platforms})"
  docker buildx build --builder miller-builder --platform "${platforms}" \
    -t "${tag}" \
    --label "org.opencontainers.image.version=${VERSION}" \
    --push "$@"
  prune "${name}"
}

prune() {
  [ -n "${DOCKERHUB_TOKEN:-}" ] || return 0
  local prefix="miller-$1-" keep="miller-$1-${VERSION}" user="${DOCKERHUB_USER:-${IMAGE_REPO%%/*}}"
  local jwt
  jwt="$(curl -fsS -X POST https://hub.docker.com/v2/users/login -H "Content-Type: application/json"     -d "{\"username\":\"${user}\",\"password\":\"${DOCKERHUB_TOKEN}\"}" | sed -E 's/.*"token":"([^"]+)".*//')"
  curl -fsS -H "Authorization: Bearer ${jwt}"     "https://hub.docker.com/v2/namespaces/${IMAGE_REPO%%/*}/repositories/${IMAGE_REPO#*/}/tags?page_size=100"     | grep -oE '"name":"[^"]+"' | cut -d'"' -f4     | while read -r old; do
        if [[ "${old}" == "${prefix}"* && "${old}" != "${keep}" ]]; then
          curl -fsS -o /dev/null -X DELETE -H "Authorization: Bearer ${jwt}"             "https://hub.docker.com/v2/namespaces/${IMAGE_REPO%%/*}/repositories/${IMAGE_REPO#*/}/tags/${old}"             && echo "    deleted old tag ${old}"
        fi
      done
}

for target in ${targets}; do
  case "${target}" in
    backend)
      build backend --label "org.opencontainers.image.revision=$(git -C src/backend rev-parse HEAD)" \
        -f docker/backend/Dockerfile.prod --build-context docker=docker/backend src/backend ;;
    frontend)
      build frontend --label "org.opencontainers.image.revision=$(git -C src/frontend rev-parse HEAD)" \
        -f docker/frontend/Dockerfile.prod --build-context nginx=docker/frontend src/frontend ;;
    *)
      echo "Unknown target: ${target}" >&2; exit 1 ;;
  esac
done
