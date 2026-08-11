#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
ARCHITECTURE="${1:-arm64}"
BUILD_ROOT="${PROJECT_ROOT}/.build/hello-word-package-${ARCHITECTURE}"
DIST_ROOT="${PROJECT_ROOT}/dist"
APP_PATH="${DIST_ROOT}/${ARCHITECTURE}/Hello, Word.app"
CONTENTS_PATH="${APP_PATH}/Contents"
MACOS_PATH="${CONTENTS_PATH}/MacOS"
RESOURCES_PATH="${CONTENTS_PATH}/Resources"
HELPERS_PATH="${RESOURCES_PATH}/Helpers"
case "${ARCHITECTURE}" in
    arm64)
        TARGET="arm64-apple-macosx13.0"
        HARPER_ARCHIVE="${PROJECT_ROOT}/Resources/Harper/harper-cli-aarch64-apple-darwin.tar.gz"
        HARPER_SHA256="218d9f2003425b334ee9c3dc2f17196761deb4fa8864b24f261cd95d61dcef3f"
        ;;
    x86_64)
        TARGET="x86_64-apple-macosx13.0"
        HARPER_ARCHIVE="${PROJECT_ROOT}/Resources/Harper/harper-cli-x86_64-apple-darwin.tar.gz"
        HARPER_SHA256="6ab3259f20fc3f3a52dd5d93c2bcc0c6753a3120b3b7acfc33101cab1f289afd"
        ;;
    *)
        print -u2 "Architecture must be arm64 or x86_64."
        exit 1
        ;;
esac

if [[ "${BUILD_ROOT}" != "${PROJECT_ROOT}/.build/hello-word-package-${ARCHITECTURE}" || "${DIST_ROOT}" != "${PROJECT_ROOT}/dist" ]]; then
    print -u2 "Refusing to build outside the project directory."
    exit 1
fi

mkdir -p "${BUILD_ROOT}" "${DIST_ROOT}/${ARCHITECTURE}"

if [[ -e "${APP_PATH}" ]]; then
    rm -rf "${APP_PATH}"
fi

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

/usr/bin/swiftc \
    -sdk "${SDK_PATH}" \
    -module-cache-path "${BUILD_ROOT}/module-cache" \
    -target "${TARGET}" \
    -O \
    -framework AppKit \
    -framework AVFoundation \
    -framework UniformTypeIdentifiers \
    "${PROJECT_ROOT}"/Sources/HelloWord/*.swift \
    -o "${BUILD_ROOT}/HelloWord"

mkdir -p "${MACOS_PATH}" "${HELPERS_PATH}" "${RESOURCES_PATH}/Placeholder Music" "${RESOURCES_PATH}/World Art"
cp "${BUILD_ROOT}/HelloWord" "${MACOS_PATH}/HelloWord"
cp "${PROJECT_ROOT}/Resources/Info.plist" "${CONTENTS_PATH}/Info.plist"
cp "${PROJECT_ROOT}/Resources/AppIcon.icns" "${RESOURCES_PATH}/AppIcon.icns"
cp "${PROJECT_ROOT}/Resources/Harper/LICENSE.txt" "${RESOURCES_PATH}/Harper LICENSE.txt"
cp "${PROJECT_ROOT}"/Resources/Placeholder\ Music/*.m4a "${RESOURCES_PATH}/Placeholder Music/"
cp "${PROJECT_ROOT}"/Resources/World\ Art/*.png "${RESOURCES_PATH}/World Art/"

ACTUAL_HARPER_SHA256="$(shasum -a 256 "${HARPER_ARCHIVE}" | awk '{print $1}')"
if [[ "${ACTUAL_HARPER_SHA256}" != "${HARPER_SHA256}" ]]; then
    print -u2 "Harper archive checksum did not match the verified build input."
    exit 1
fi

tar -xzf "${HARPER_ARCHIVE}" -C "${HELPERS_PATH}"
chmod 755 "${MACOS_PATH}/HelloWord" "${HELPERS_PATH}/harper-cli"

codesign --force --deep --sign - "${APP_PATH}"
codesign --verify --deep --strict "${APP_PATH}"

print "Built ${APP_PATH}"
