#!/usr/bin/env bash
set -euo pipefail

platform="${1:?Usage: ci-build-metadata.sh <ios|android> [manual-version]}"
manual_version="${2:-0.0.0}"
ref_name="${GITHUB_REF_NAME:-local}"
ref_type="${GITHUB_REF_TYPE:-branch}"
run_number="${GITHUB_RUN_NUMBER:-0}"
sha="${GITHUB_SHA:-$(git rev-parse HEAD)}"
short_sha="${sha:0:7}"

if [[ "$ref_type" == "tag" && "$ref_name" == "$platform-v"* ]]; then
    release_name="${ref_name#"$platform-v"}"
    version="${release_name%%-*}"
    label="$ref_name-$short_sha"
elif [[ "$ref_type" == "tag" && "$ref_name" == "all-v"* ]]; then
    release_name="${ref_name#all-v}"
    version="${release_name%%-*}"
    label="$platform-$ref_name-$short_sha"
else
    version="$manual_version"
    label="$platform-manual-$run_number-$short_sha"
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version '$version'. Use semantic version X.Y.Z or a tag such as $platform-v1.2.3-test1 or all-v1.2.3-test1." >&2
    exit 1
fi

build_number="$run_number"
if (( build_number < 1 )); then
    build_number=1
fi
# Keep CI Android builds upgradeable from the inherited 202608150 build while
# retaining the workflow run number as the unique, human-readable suffix.
version_code=$((300000000 + build_number))

printf 'version=%s\n' "$version"
printf 'build_number=%s\n' "$build_number"
printf 'version_code=%s\n' "$version_code"
printf 'label=%s\n' "$label"
