#!/bin/sh
set -eu

embedded_framework="${TARGET_BUILD_DIR:?}/${FRAMEWORKS_FOLDER_PATH:?}/TraccarClientSDK.framework"
sdk_binary="${BUILT_PRODUCTS_DIR:?}/TraccarClientSDK.framework/TraccarClientSDK"

[ -d "$embedded_framework" ] || exit 0

# SDK 1.0.11 is static: its code and debug symbols are linked into Runner and
# LocationPushService. SwiftPM also embeds the framework, which Xcode replaces
# with an empty dylib stub during archiving. That stub triggers a missing-dSYM
# warning on upload. Remove the redundant bundle before the app is signed.
# Preserve the framework if a future SDK release switches to dynamic linking.
if /usr/bin/file -b "$sdk_binary" | /usr/bin/grep -q 'current ar archive'; then
    /bin/rm -rf -- "$embedded_framework"
fi
