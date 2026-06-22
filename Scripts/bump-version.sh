#!/bin/bash
# Bumps CURRENT_PROJECT_VERSION on every build and MARKETING_VERSION on archive (last component).
# Updates both the source pbxproj (for future builds) and the just-generated Info.plist
# (so the current build/archive carries the new numbers).

set -e

PBXPROJ="${PROJECT_FILE_PATH}/project.pbxproj"
INFO_PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

if [ ! -f "$PBXPROJ" ]; then
    echo "warning: pbxproj not found at $PBXPROJ, skipping version bump"
    exit 0
fi

current_build=$(/usr/bin/sed -n 's/.*CURRENT_PROJECT_VERSION = \([0-9][0-9]*\);.*/\1/p' "$PBXPROJ" | /usr/bin/sort -nu | /usr/bin/tail -1)
new_build=$((current_build + 1))

/usr/bin/sed -i '' "s/CURRENT_PROJECT_VERSION = ${current_build};/CURRENT_PROJECT_VERSION = ${new_build};/g" "$PBXPROJ"

if [ -f "$INFO_PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${new_build}" "$INFO_PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${new_build}" "$INFO_PLIST"
fi

echo "Bumped CURRENT_PROJECT_VERSION: ${current_build} -> ${new_build}"

# Marketing version: only on Archive (xcodebuild sets ACTION=install).
if [ "$ACTION" = "install" ]; then
    current_mv=$(/usr/bin/sed -n 's/.*MARKETING_VERSION = \([0-9][0-9.]*\);.*/\1/p' "$PBXPROJ" | /usr/bin/head -1)

    IFS='.' read -r -a parts <<< "$current_mv"
    last_idx=$((${#parts[@]} - 1))
    parts[$last_idx]=$((parts[last_idx] + 1))
    new_mv=$(IFS='.'; echo "${parts[*]}")

    /usr/bin/sed -i '' "s/MARKETING_VERSION = ${current_mv};/MARKETING_VERSION = ${new_mv};/g" "$PBXPROJ"

    if [ -f "$INFO_PLIST" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${new_mv}" "$INFO_PLIST" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${new_mv}" "$INFO_PLIST"
    fi

    echo "Bumped MARKETING_VERSION: ${current_mv} -> ${new_mv}"
fi
