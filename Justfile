# ── Configurable variables ───────────────────────────────────────────────────
# Developer ID Application certificate (set with CODESIGN_IDENTITY=... just sign)
CODESIGN_IDENTITY := env_var_or_default("CODESIGN_IDENTITY", "")

# Keychain profile for notarytool — set up once with:
#   xcrun notarytool store-credentials "scm-notarytool" \
#     --apple-id <your-apple-id> --team-id <your-team-id> \
#     --password <app-specific-password>
NOTARYTOOL_PROFILE := env_var_or_default("NOTARYTOOL_PROFILE", "scm-notarytool")

INSTALL_DIR := env_var_or_default("INSTALL_DIR", env_var("HOME") + "/.local/bin")

# Linux builds run inside the official Swift image. Jammy (glibc 2.35) keeps the
# binary compatible with Ubuntu 22.04+ and Debian 12+. Use CONTAINER_CLI=container
# for Apple's container tool.
CONTAINER_CLI := env_var_or_default("CONTAINER_CLI", "docker")
SWIFT_LINUX_IMAGE := env_var_or_default("SWIFT_LINUX_IMAGE", "swift:6.2-jammy")

# Debian package name — `scm` is already taken in Debian (a Scheme interpreter)
DEB_PACKAGE := "swift-cardano-multitool"
DEB_MAINTAINER := env_var_or_default("DEB_MAINTAINER", "Kingpin Apps <hadderley@kingpinapps.com>")

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
release-universal: (release-arch "arm64") (release-arch "x86_64") lipo-universal

# Release build for one macOS architecture (arm64 or x86_64)
release-arch arch:
    swift build -c release --arch {{ arch }}

# Combine per-arch release binaries into .build/universal/release/scm. CI builds
# each arch in its own job and passes the downloaded binaries here.
lipo-universal arm64=".build/arm64-apple-macosx/release/scm" x86_64=".build/x86_64-apple-macosx/release/scm":
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p .build/universal/release
    lipo -create -output .build/universal/release/scm "{{ arm64 }}" "{{ x86_64 }}"
    echo "✓ Universal binary ready (architectures: $(lipo -archs .build/universal/release/scm))"

# Codesign the universal binary (builds it first)
sign: release-universal sign-only

# Codesign an already-built universal binary (CI builds it in a separate step)
sign-only:
    #!/usr/bin/env bash
    # No release-universal dependency here: CI already built the binary, and
    # rebuilding it a second time is what pushed the release job past its timeout.
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

# ── Linux distribution ───────────────────────────────────────────────────────

# Build a stripped Linux release binary for the host arch → .build/linux/scm
release-linux:
    {{ CONTAINER_CLI }} run --rm -v "{{ justfile_directory() }}":/src -w /src {{ SWIFT_LINUX_IMAGE }} \
        bash -c 'set -e; swift build -c release --static-swift-stdlib --scratch-path .build/linux \
            && cp .build/linux/release/scm .build/linux/scm && strip .build/linux/scm'
    @echo "✓ Linux binary ready at .build/linux/scm"

# Package .build/linux/scm as a tarball + .deb into dist/ (arch: amd64 or arm64)
package-linux version arch:
    #!/usr/bin/env bash
    set -euo pipefail
    VERSION="{{ version }}"
    ARCH="{{ arch }}"
    case "$ARCH" in
        amd64) UNAME_ARCH=x86_64 ;;
        arm64) UNAME_ARCH=aarch64 ;;
        *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
    esac
    mkdir -p dist
    tar -czf "dist/scm-${VERSION}-linux-${UNAME_ARCH}.tar.gz" -C .build/linux scm

    ROOT=$(mktemp -d)
    trap 'rm -rf "$ROOT"' EXIT
    install -Dm755 .build/linux/scm "$ROOT/usr/bin/scm"
    install -Dm644 LICENSE "$ROOT/usr/share/doc/{{ DEB_PACKAGE }}/copyright"
    mkdir -p "$ROOT/DEBIAN"
    cat > "$ROOT/DEBIAN/control" <<EOF
    Package: {{ DEB_PACKAGE }}
    Version: ${VERSION}
    Architecture: ${ARCH}
    Maintainer: {{ DEB_MAINTAINER }}
    Installed-Size: $(du -sk "$ROOT/usr" | cut -f1)
    Depends: libc6 (>= 2.35), libcurl4, libstdc++6, libgcc-s1
    Conflicts: scm
    Section: utils
    Priority: optional
    Homepage: https://github.com/Kingpin-Apps/swift-cardano-multitool
    Description: TUI for Cardano blockchain interactions
     scm manages the Cardano ecosystem from the terminal: installing and running
     node software, generating keys, building and submitting transactions,
     querying on-chain data, and working with air-gapped machines.
    EOF
    dpkg-deb --root-owner-group -Zxz --build "$ROOT" "dist/{{ DEB_PACKAGE }}_${VERSION}_${ARCH}.deb"
    echo "✓ Packaged dist/scm-${VERSION}-linux-${UNAME_ARCH}.tar.gz + dist/{{ DEB_PACKAGE }}_${VERSION}_${ARCH}.deb"

# Add dist/*.deb to a checkout of the APT repo (Kingpin-Apps/apt, served by GitHub
# Pages), regenerate the indexes and sign them. Needs apt-utils + a GPG secret key
# in the keyring (APT_GPG_KEY_ID, else the first secret key; APT_GPG_PASSPHRASE if set).
# The Release workflow calls this automatically, keeping the newest `keep` versions.
apt-publish repo_dir="apt-repo" keep="3":
    #!/usr/bin/env bash
    set -euo pipefail
    REPO="{{ repo_dir }}"
    POOL="$REPO/pool/main/s/{{ DEB_PACKAGE }}"
    mkdir -p "$POOL"
    cp dist/*.deb "$POOL/"
    ls "$POOL"/*.deb | sed -E 's|.*_([^_]+)_[^_]+\.deb$|\1|' | sort -uV | head -n -{{ keep }} \
        | while read -r old; do rm -f "$POOL"/*_"${old}"_*.deb; done

    KEY_ID="${APT_GPG_KEY_ID:-$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr/ {print $10; exit}')}"
    GPG=(gpg --batch --yes --pinentry-mode loopback --local-user "$KEY_ID")
    [ -n "${APT_GPG_PASSPHRASE:-}" ] && GPG+=(--passphrase "$APT_GPG_PASSPHRASE")

    cd "$REPO"
    DIST=dists/stable
    rm -rf "$DIST"
    for arch in amd64 arm64; do
        mkdir -p "$DIST/main/binary-$arch"
        apt-ftparchive --arch "$arch" packages pool > "$DIST/main/binary-$arch/Packages"
        gzip -9kf "$DIST/main/binary-$arch/Packages"
    done
    apt-ftparchive \
        -o APT::FTPArchive::Release::Origin="Kingpin Apps" \
        -o APT::FTPArchive::Release::Label="Kingpin Apps" \
        -o APT::FTPArchive::Release::Suite=stable \
        -o APT::FTPArchive::Release::Codename=stable \
        -o APT::FTPArchive::Release::Architectures="amd64 arm64" \
        -o APT::FTPArchive::Release::Components=main \
        release "$DIST" > Release.tmp
    mv Release.tmp "$DIST/Release"
    "${GPG[@]}" --clearsign -o "$DIST/InRelease" "$DIST/Release"
    "${GPG[@]}" --armor --detach-sign -o "$DIST/Release.gpg" "$DIST/Release"
    gpg --batch --yes --export "$KEY_ID" > kingpin-apps.gpg
    touch .nojekyll
    echo "✓ APT repo updated in $REPO (signed with $KEY_ID)"

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
