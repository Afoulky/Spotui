#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
    echo "iOS compilation requires macOS and Xcode. Use the 'Build MeloBridge' GitHub Actions workflow." >&2
    exit 1
fi

if ! command -v xcodegen >/dev/null; then
    echo "Install XcodeGen with: brew install xcodegen" >&2
    exit 1
fi
xcodebuild -version

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="$repo_root/build/ios"
app_version="${MELOBRIDGE_VERSION:-0.1.0}"
build_number="${MELOBRIDGE_BUILD_NUMBER:-1}"
artifact_label="${MELOBRIDGE_ARTIFACT_LABEL:-ios-local}"
mkdir -p "$output_dir"
xcodegen generate --spec "$repo_root/iosApp/project.yml" --project "$repo_root/iosApp"

# Build for real devices, without requesting Apple credentials or provisioning.
# A static Kotlin framework is linked into the executable by Xcode.
xcodebuild \
    -project "$repo_root/iosApp/MeloBridge.xcodeproj" \
    -scheme MeloBridge \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$output_dir/DerivedData" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY= \
    MARKETING_VERSION="$app_version" \
    CURRENT_PROJECT_VERSION="$build_number" \
    build

app_path="$output_dir/DerivedData/Build/Products/Release-iphoneos/MeloBridge.app"
test -f "$app_path/MeloBridge"
# Use a fresh staging directory: stale files must never leak into an IPA.
staging_dir="$(mktemp -d "$output_dir/package.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
mkdir "$staging_dir/Payload"
ditto "$app_path" "$staging_dir/Payload/MeloBridge.app"
ipa_name="MeloBridge-$artifact_label-unsigned.ipa"
(cd "$staging_dir" && /usr/bin/zip -qry "$ipa_name" Payload)
mv "$staging_dir/$ipa_name" "$output_dir/$ipa_name"
echo "Unsigned IPA: $output_dir/$ipa_name ($app_version build $build_number)"
