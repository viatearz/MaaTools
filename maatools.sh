#!/bin/bash
set -euo pipefail

BUNDLE_ID=""
EXECUTABLE=""
MAATOOLS_CONFIG=""
SANDBOX_PROFILE=""
ENTITLEMENTS=""

print_localized_string() {
    case "$LANG" in
        zh_CN*) echo "$1" ;;
        *)      echo "$2" ;;
    esac
}

plist_get() {
    local plist="$1"
    local key="$2"
    /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null
}

init_globals() {
    BUNDLE_ID="$2"

    local bundle_path="$HOME/Library/Containers/io.playcover.PlayCover/Applications/$BUNDLE_ID.app"
    if ! [ -d "$bundle_path" ]; then
        print_localized_string \
            "错误：未安装 ${BUNDLE_ID}，或 PlayCover 版本过低（需要 3.0 及以上版本）。" \
            "Error: ${BUNDLE_ID} is not installed, or your PlayCover version is too old (3.0 or later is required)."
        exit 1
    fi

    EXECUTABLE=$bundle_path/$(plist_get "$bundle_path/Info.plist" CFBundleExecutable)

    MAATOOLS_CONFIG="${bundle_path%.app}.maa.json"

    SANDBOX_PROFILE="$HOME/.config/PlayCover/$BUNDLE_ID.yaml"

    ENTITLEMENTS=$(mktemp)
}

create_maatools_config() {
    echo "Creating MaaTools config..."

    if [ ! -f "$MAATOOLS_CONFIG" ]; then
        printf "{\n\t\"enabled\": 1,\n\t\"port\": 1717,\n\t\"debug\": 0\n}" > "$MAATOOLS_CONFIG"
    fi
}

delete_maatools_config() {
    echo "Deleting MaaTools config..."

    rm -f "$MAATOOLS_CONFIG"
}

create_sandbox_profile() {
    echo "Creating sandbox profile..."

    mkdir -p "$(dirname "$SANDBOX_PROFILE")"

    rm -f "$SANDBOX_PROFILE"

    cp /Applications/PlayCover.app/Contents/Resources/default.yaml "$SANDBOX_PROFILE"

    sed -i '' '/PlayTools.framework/{
        p
        s/PlayTools/MaaTools/
    }' "$SANDBOX_PROFILE"
}

delete_sandbox_profile() {
    echo "Deleting sandbox profile..."

    rm -f "$SANDBOX_PROFILE"
}

add_entry_to_entitlements() {
    echo "Adding entry to entitlements..."

    codesign -d --xml --entitlements "$ENTITLEMENTS" "$EXECUTABLE" >/dev/null 2>&1

    xmllint --format "$ENTITLEMENTS" --output "$ENTITLEMENTS"

    if ! grep -q "PlayTools.framework" "$ENTITLEMENTS"; then
        print_localized_string \
            "错误：未检测到 PlayTools。请在 PlayCover > 应用设置 > 杂项 中注入 PlayTools。" \
            "Error: PlayTools was not detected. Please inject PlayTools in PlayCover > App Settings > Misc."
        exit 1
    fi

    if ! grep -q "MaaTools.framework" "$ENTITLEMENTS"; then
        sed -i '' '/PlayTools.framework/{
            p
            s/PlayTools/MaaTools/
        }' "$ENTITLEMENTS"
    fi
}

remove_entry_from_entitlements() {
    echo "Removing entry from entitlements..."

    codesign -d --xml --entitlements "$ENTITLEMENTS" "$EXECUTABLE" >/dev/null 2>&1

    xmllint --format "$ENTITLEMENTS" --output "$ENTITLEMENTS"

    sed -i '' '/MaaTools.framework/d' "$ENTITLEMENTS"
}

is_injected() {
    local executable="$1"
    local framework="$2"
    otool -l "$executable" 2>/dev/null | grep -q "$framework"
}

inject_maatools() {
    echo "Injecting MaaTools..."

    xattr -dr com.apple.quarantine ./MaaTools.framework
    rm -rf "$HOME/Library/Frameworks/MaaTools.framework"
    cp -r ./MaaTools.framework "$HOME/Library/Frameworks/MaaTools.framework"

    if ! is_injected "$EXECUTABLE" "MaaTools.framework"; then
        # See https://github.com/paradiseduo/inject
        xattr -dr com.apple.quarantine ./inject
        ./inject "$EXECUTABLE" -d "$HOME/Library/Frameworks/MaaTools.framework/MaaTools" >/dev/null
    fi
}

remove_maatools() {
    echo "Removing MaaTools..."

    if is_injected "$EXECUTABLE" "MaaTools.framework"; then
        # See https://github.com/paradiseduo/inject
        xattr -dr com.apple.quarantine ./inject
        ./inject "$EXECUTABLE" -d "$HOME/Library/Frameworks/MaaTools.framework/MaaTools" --remove >/dev/null
    fi
}

resign() {
    echo "Resigning..."
    codesign -fs- --deep --entitlements "$ENTITLEMENTS" "$EXECUTABLE"
}

cleanup() {
    echo "Cleaning up..."

    local injected=0

    local app_root="$HOME/Library/Containers/io.playcover.PlayCover/Applications"
    local app_list=$(find "$app_root" -maxdepth 1 -type d -name "*.app")
    for app_dir in $app_list; do
        local executable="$app_dir/$(plist_get "$app_dir/Info.plist" CFBundleExecutable)"
        if is_injected "$executable" "MaaTools.framework"; then
            injected=1
            break
        fi
    done

    if [ $injected -eq 0 ]; then
        rm -rf "$HOME/Library/Frameworks/MaaTools.framework" 
    fi
}

usage() {
    cat <<EOF
Usage:
    maatools install <bundle_id>
        Install MaaTools for the specified app.

    maatools uninstall <bundle_id>
        Uninstall MaaTools from the specified app.

    maatools list
        List all apps and their MaaTools injection status.
EOF
}

install() {
    init_globals "$@"
    create_maatools_config
    create_sandbox_profile
    add_entry_to_entitlements
    inject_maatools
    resign
    echo "Done"
}

uninstall() {
    init_globals "$@"
    delete_maatools_config
    delete_sandbox_profile
    remove_entry_from_entitlements
    remove_maatools
    resign
    cleanup
    echo "Done"
}

list_apps() {
    {
        echo "App Name\tBundle ID\tInjected"
        echo "--------\t--------\t--------"

        local app_root="$HOME/Library/Containers/io.playcover.PlayCover/Applications"
        local app_list=$(find "$app_root" -maxdepth 1 -type d -name "*.app")
        for app_dir in $app_list; do
            local plist="$app_dir/Info.plist"

            local app_name bundle_id executable injected="No"

            app_name=$(plist_get "$plist" CFBundleDisplayName)

            if [ -z "$app_name" ]; then
                app_name=$(plist_get "$plist" CFBundleName)
            fi

            bundle_id=$(plist_get "$plist" CFBundleIdentifier)

            executable="$app_dir/$(plist_get "$plist" CFBundleExecutable)"

            if is_injected "$executable" "MaaTools.framework"; then
                injected="Yes"
            fi

            echo "$app_name\t$bundle_id\t$injected"
        done
    } | column -t -s $'\t'
}

main() {
    local command="${1:-help}"

    case "$command" in
        install)
            install "$@"
            ;;
        uninstall)
            uninstall "$@"
            ;;
        list)
            list_apps
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            echo "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
