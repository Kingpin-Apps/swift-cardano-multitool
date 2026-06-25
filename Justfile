# ── Configurable variables ───────────────────────────────────────────────────
# Developer ID Application certificate (set with CODESIGN_IDENTITY=... just sign)
CODESIGN_IDENTITY := env_var_or_default("CODESIGN_IDENTITY", "")

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

# Regenerate Version.swift from the current cz.json version
version-file:
	#!/usr/bin/env bash
	set -euo pipefail
	VERSION=$(jq -r '.commitizen.version' cz.json)
	echo "Generating Version.swift for v$VERSION..."
	swift package --allow-writing-to-package-directory version-file --create "$VERSION"

# Bump version according to changelog and regenerate Version.swift
bump: changelog
	cz bump

# Update the Homebrew tap formula (Kingpin-Apps/homebrew-tap → Formula/scm.rb) to
# point at a release's universal tarball + sha256. The Release workflow calls this
# automatically; run manually to recover a release, e.g. `just tap-bump 0.8.0`.
# Pass a local tarball as the 2nd arg to skip the download when computing sha256.
tap-bump version tarball="":
	#!/usr/bin/env bash
	set -euo pipefail
	VERSION="{{ version }}"
	TARBALL="{{ tarball }}"
	TAP="Kingpin-Apps/homebrew-tap"
	FORMULA="Formula/scm.rb"
	URL="https://github.com/Kingpin-Apps/swift-cardano-multitool/releases/download/${VERSION}/scm-${VERSION}-macos-universal.tar.gz"
	WORK=$(mktemp -d)
	trap 'rm -rf "$WORK"' EXIT
	if [ -n "$TARBALL" ] && [ -f "$TARBALL" ]; then
	    SHA256=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
	else
	    echo "Downloading release asset to compute sha256..."
	    curl --fail --location --silent --show-error -o "$WORK/asset.tar.gz" "$URL"
	    SHA256=$(shasum -a 256 "$WORK/asset.tar.gz" | awk '{print $1}')
	fi
	gh api "repos/${TAP}/contents/${FORMULA}" > "$WORK/resp.json"
	jq -r '.content' "$WORK/resp.json" | base64 --decode > "$WORK/formula.rb"
	FILE_SHA=$(jq -r '.sha' "$WORK/resp.json")
	sed -i.bak -E "s|^( *url )\".*\"|\\1\"${URL}\"|" "$WORK/formula.rb"
	sed -i.bak -E "s|^( *sha256 )\".*\"|\\1\"${SHA256}\"|" "$WORK/formula.rb"
	rm -f "$WORK/formula.rb.bak"
	echo "→ formula now:"
	grep -E '^[[:space:]]*(url|sha256) ' "$WORK/formula.rb"
	gh api "repos/${TAP}/contents/${FORMULA}" -X PUT \
	    -f message="scm ${VERSION}" \
	    -f content="$(base64 -i "$WORK/formula.rb" | tr -d '\n')" \
	    -f sha="$FILE_SHA" \
	    -f branch="main"
	echo "✓ Bumped ${TAP} → ${VERSION}"
