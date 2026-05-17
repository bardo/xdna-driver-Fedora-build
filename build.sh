#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 [-h] [-n]"
    echo "Options:"
    echo "  -h: print usage information"
    echo "  -n: do not use Podman's cache (fetch latest git revision)"
}

cache=""
while getopts "hn" opt ; do
    case $opt in
        h) usage ; exit 0 ;;
        n) cache="--no-cache" ;;
        \?) echo "Invalid option: -$OPTARG" usage ; exit 1 ;;
    esac
done

shift $(( OPTIND -1 ))

[[ $# -ne 0 ]] && ( usage ; exit 1 )

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

podman build $cache --file "${dockerfile}" --tag "${image_tag}" "${script_dir}"

container_id="$(podman create "${image_tag}")"
cleanup() {
    podman rm -f "${container_id}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

podman cp "${container_id}:/artifacts/." "${artifact_dir}/"
