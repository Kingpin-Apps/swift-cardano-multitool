# syntax=docker/dockerfile:1

# scm is built *before* this image, not inside it. `just release-linux` compiles
# with --static-swift-stdlib, so the Swift runtime is already baked into the
# binary and this image needs no Swift toolchain — only the few libraries the
# binary still links dynamically. Building from source here would duplicate the
# multi-arch build the release workflow already does, for no benefit.
#
# The build context must therefore contain the prebuilt binaries laid out by
# architecture, matching the TARGETARCH values buildx sets:
#
#     <context>/amd64/scm
#     <context>/arm64/scm
#
# `just docker-build` assembles that for the host architecture; the release
# workflow assembles both from the dist-linux-* artifacts.
FROM ubuntu:22.04

# Jammy is deliberate: the binary is built against glibc 2.35, so this base
# matches its floor and the image stays compatible with the same platforms as
# the .deb (Ubuntu 22.04+, Debian 12+).
#
# The base already carries libc6, libstdc++6 and libgcc-s1. It does NOT carry
# libcurl4, and without it scm dies on startup with
#   error while loading shared libraries: libcurl.so.4
# ca-certificates is needed for TLS to Blockfrost, Koios and Ogmios.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libcurl4 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ARG TARGETARCH
COPY ${TARGETARCH}/scm /usr/local/bin/scm

# scm reads its configuration and keys from $HOME/.scm. Running as a normal user
# means a config mounted read-only behaves the same way it does on the host, and
# nothing in the container can write to it by accident.
RUN useradd --create-home --shell /bin/bash scm
USER scm
WORKDIR /home/scm

# scm is an interactive TUI, so the useful invocation is `docker run -it …`.
# Subcommands still work without a TTY: `docker run --rm … scm --version`.
ENTRYPOINT ["/usr/local/bin/scm"]

LABEL org.opencontainers.image.title="scm" \
      org.opencontainers.image.description="TUI for Cardano blockchain interactions" \
      org.opencontainers.image.source="https://github.com/Kingpin-Apps/swift-cardano-multitool" \
      org.opencontainers.image.licenses="MIT"
