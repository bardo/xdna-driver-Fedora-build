#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dockerfile="${script_dir}/xdna-driver.Dockerfile"
artifact_dir="${script_dir}/build"
image_tag="${IMAGE_TAG:-xdna-driver-fedora-build:latest}"

if ! command -v podman >/dev/null 2>&1; then
    echo "podman is required but was not found in PATH" >&2
    exit 1
fi

if [[ ! -f "${dockerfile}" ]]; then
    echo "Dockerfile not found: ${dockerfile}" >&2
    exit 1
fi

mkdir -p "${artifact_dir}"
rm -f "${artifact_dir}"/*.rpm

podman build --file "${dockerfile}" --tag "${image_tag}" "${script_dir}"

container_id="$(podman create "${image_tag}")"
cleanup() {
    podman rm -f "${container_id}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

podman cp "${container_id}:/artifacts/." "${artifact_dir}/"
