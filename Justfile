# ── Configurable variables ───────────────────────────────────────────────────
# Developer ID Application certificate (set with CODESIGN_IDENTITY=... just sign)
CODESIGN_IDENTITY := env_var("CODESIGN_IDENTITY")

# Keychain profile for notarytool — set up once with:
#   xcrun notarytool store-credentials "scm-notarytool" \
#     --apple-id <your-apple-id> --team-id <your-team-id> \
#     --password <app-specific-password>
NOTARYTOOL_PROFILE := env_var_or_default("NOTARYTOOL_PROFILE", "scm-notarytool")

INSTALL_DIR := env_var_or_default("INSTALL_DIR", env_var("HOME") + "/.local/bin")

# ── Dev tasks ────────────────────────────────────────────────────────────────
run:
    swift run

build:
    swift build

clean:
    swift package clean

test:
    swift test

# Build for the current host architecture only (fast, for development)
release:
    swift build -c release

# ── Distribution tasks ───────────────────────────────────────────────────────

# Build universal binary (arm64 + x86_64) via lipo
release-universal:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building arm64..."
    swift build -c release --arch arm64
    echo "Building x86_64..."
    swift build -c release --arch x86_64
    echo "Combining with lipo..."
    mkdir -p .build/universal/release
    lipo -create \
        -output .build/universal/release/scm \
        .build/arm64-apple-macosx/release/scm \
        .build/x86_64-apple-macosx/release/scm
    echo "✓ Universal binary ready (architectures: $(lipo -archs .build/universal/release/scm))"

# Codesign the universal binary
sign: release-universal
    #!/usr/bin/env bash
    set -euo pipefail
    BIN_PATH="{{ justfile_directory() }}/.build/universal/release"
    echo "Signing binary..."
    codesign --sign "{{ CODESIGN_IDENTITY }}" \
             --options runtime \
             --timestamp \
             --force \
             "$BIN_PATH/scm"
    echo "Verifying..."
    codesign --verify --verbose "$BIN_PATH/scm"
    echo "✓ Signed scm (architectures: $(lipo -archs "$BIN_PATH/scm"))"

# Notarize for Gatekeeper / Homebrew distribution (requires keychain profile — see above)
notarize: sign
    #!/usr/bin/env bash
    set -euo pipefail
    BIN_PATH="{{ justfile_directory() }}/.build/universal/release"
    STAGING=$(mktemp -d)
    trap 'rm -rf "$STAGING"' EXIT
    cp "$BIN_PATH/scm" "$STAGING/"
    ZIPFILE=$(mktemp /tmp/scm-notarize-XXXXXX.zip)
    ditto -c -k --keepParent "$STAGING" "$ZIPFILE"
    echo "Submitting to Apple Notary Service..."
    xcrun notarytool submit "$ZIPFILE" \
        --keychain-profile "{{ NOTARYTOOL_PROFILE }}" \
        --wait
    rm -f "$ZIPFILE"
    echo "✓ Notarization complete"

# Build universal binary, codesign, and install to $INSTALL_DIR
install: sign
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "{{ INSTALL_DIR }}"
    cp "{{ justfile_directory() }}/.build/universal/release/scm" "{{ INSTALL_DIR }}/scm"
    echo "✓ Installed scm to {{ INSTALL_DIR }}"

uninstall:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -f "{{ INSTALL_DIR }}/scm"
    echo "✓ Uninstalled scm from {{ INSTALL_DIR }}"

# ── Release management ───────────────────────────────────────────────────────

# Update changelog
changelog:
	cz ch

# Bump version according to changelog
bump: changelog
	cz bump
