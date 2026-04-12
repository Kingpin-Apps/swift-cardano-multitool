run:
    swift run

build:
    swift build
    
clean:
    swift package clean

test:
    swift test

release:
    swift build -c release

install: release
    #!/usr/bin/env bash
    set -euo pipefail
    BINARY_PATH=$(swift build -c release --show-bin-path)
    INSTALL_DIR="$HOME/.local/bin"
    MANIFEST="$INSTALL_DIR/.scm-bundles"
    mkdir -p "$INSTALL_DIR"
    cp "$BINARY_PATH/scm" "$INSTALL_DIR/scm"
    # Reset manifest
    : > "$MANIFEST"
    shopt -s nullglob
    for bundle in "$BINARY_PATH"/*.bundle; do
        [ -d "$bundle" ] || continue
        # Skip bundles with no runtime resources (doc-only or privacy-manifest-only)
        real_files=$(find "$bundle" -type f ! -name "PrivacyInfo.xcprivacy" | grep -cv '\.docc/' || true)
        [ "$real_files" -gt 0 ] || continue
        cp -R "$bundle" "$INSTALL_DIR/"
        echo "$(basename "$bundle")" >> "$MANIFEST"
    done
    echo "Installed scm to $INSTALL_DIR"

uninstall:
    #!/usr/bin/env bash
    set -euo pipefail
    INSTALL_DIR="$HOME/.local/bin"
    MANIFEST="$INSTALL_DIR/.scm-bundles"
    rm -f "$INSTALL_DIR/scm"
    if [ -f "$MANIFEST" ]; then
        while IFS= read -r bundle; do
            rm -rf "${INSTALL_DIR:?}/$bundle"
        done < "$MANIFEST"
        rm -f "$MANIFEST"
    fi
    echo "Uninstalled scm from $INSTALL_DIR"

# Update changelog
changelog:
	cz ch
    
# Bump version according to changelog
bump: changelog
	cz bump
