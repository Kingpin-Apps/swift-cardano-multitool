# scm — Swift Cardano Multitool

An interactive terminal UI and CLI for the Cardano blockchain: keys, addresses,
transactions, stake pools, Conway-era governance, native assets and air-gapped
workflows, in one static binary.

- **Source & full docs:** https://github.com/Kingpin-Apps/swift-cardano-multitool
- **Issues:** https://github.com/Kingpin-Apps/swift-cardano-multitool/issues
- **Changelog:** https://github.com/Kingpin-Apps/swift-cardano-multitool/blob/main/CHANGELOG.md
- **Also published at:** `ghcr.io/kingpin-apps/scm`

## Tags

| Tag | Meaning |
|-----|---------|
| `latest` | The most recent release |
| `<version>` (e.g. `0.15.2`) | A specific release — pin this in scripts and CI |

Every tag is multi-arch: `linux/amd64` and `linux/arm64`.

## Quick start

`scm` is an interactive TUI, so **`-it` is required** for the menus:

```bash
docker run -it --rm kingpinapps/scm
```

Subcommands also run headless, which is what you want in scripts and CI:

```bash
docker run --rm kingpinapps/scm --version
docker run --rm kingpinapps/scm --help
```

## Using your configuration and keys

Configuration and keys stay on the host. Mount the directory holding them
read-only and point `CARDANO_MULTITOOL_CONFIG` at the config file *inside* the
container — the variable is required, since `scm` has no default search path.

```bash
docker run -it --rm \
  -v "$HOME/.scm:/home/scm/.scm:ro" \
  -e CARDANO_MULTITOOL_CONFIG=/home/scm/.scm/config-mainnet.json \
  kingpinapps/scm
```

Paths *inside* a config file are resolved in the container. Anything they point
at — a `cardano-node` socket, a key directory — must be mounted at the same path.
Remote backends (Blockfrost, Koios, Ogmios) need nothing extra.

To work with files from the host, mount them too:

```bash
docker run --rm \
  -v "$HOME/.scm:/home/scm/.scm:ro" \
  -v "$PWD:/work:ro" \
  -e CARDANO_MULTITOOL_CONFIG=/home/scm/.scm/config-mainnet.json \
  kingpinapps/scm transaction validate --tx-file /work/tx.json --json
```

## Environment variables

| Variable | Description |
|----------|-------------|
| `CARDANO_MULTITOOL_CONFIG` | Path to the config file (JSON, TOML or YAML) |
| `BLOCKFROST_PROJECT_ID` | Blockfrost API project ID |
| `CARDANO_MULTITOOL_SKIP_PROMPT` | `1` skips interactive confirmations |
| `CARDANO_MULTITOOL_DECRYPT_PASSWORD` | Pre-supplies a decryption password |
| `CARDANO_NODE_SOCKET_PATH` | Local node socket path |

See the [full list](https://github.com/Kingpin-Apps/swift-cardano-multitool#environment-variables).

## What's in the image

- Ubuntu 22.04 base with `libcurl4` and `ca-certificates`
- `/usr/local/bin/scm` as the entrypoint (statically linked Swift runtime)
- Runs as the unprivileged `scm` user, with `/home/scm` as its home and working directory
- No configuration, keys or API credentials are baked in

## License

MIT — see [LICENSE](https://github.com/Kingpin-Apps/swift-cardano-multitool/blob/main/LICENSE).
