# Getting Started

Install `scm` and run your first commands.

## Overview

`scm` (Swift Cardano Multitool) is a single binary with no runtime dependencies beyond a Cardano node socket (for commands that query the chain). This guide covers installation and first steps.

## Requirements

- macOS 15 or later (Apple Silicon or Intel), or Linux: Ubuntu 22.04+ / Debian 12+ (x86_64 or arm64)
- Swift 6.2 or later (only to build from source)
- A running `cardano-node` (required only for `query`, `run`, and `transaction` commands)

## Installation

### Homebrew (macOS)

Install the signed, notarized universal binary (Apple Silicon and Intel) from the Kingpin Apps tap:

```bash
brew install Kingpin-Apps/tap/scm
```

Upgrade later with `brew upgrade scm`.

### APT (Debian / Ubuntu)

Add the Kingpin Apps APT repository and install the `swift-cardano-multitool` package, which provides the `scm` command:

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://kingpin-apps.github.io/apt/kingpin-apps.gpg | sudo tee /etc/apt/keyrings/kingpin-apps.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/kingpin-apps.gpg] https://kingpin-apps.github.io/apt stable main" | sudo tee /etc/apt/sources.list.d/kingpin-apps.list
sudo apt update
sudo apt install swift-cardano-multitool
```

Upgrade later with `sudo apt update && sudo apt upgrade`. The package conflicts with Debian's unrelated `scm` (Scheme) package, which also installs `/usr/bin/scm`.

### Release downloads

Every [GitHub release](https://github.com/Kingpin-Apps/swift-cardano-multitool/releases) has the macOS universal binary, Linux tarballs (`scm-<version>-linux-x86_64.tar.gz`, `scm-<version>-linux-aarch64.tar.gz`) and `.deb` packages. The Linux binaries need `libcurl4`.

### Build from source

Clone the repository and build with Swift Package Manager:

```bash
git clone https://github.com/Kingpin-Apps/swift-cardano-multitool.git
cd swift-cardano-multitool
swift build -c release
cp .build/release/scm ~/.local/bin/scm
```

### Install with just

The project includes a `Justfile` for building a signed universal binary (arm64 + x86_64) and installing it in one step:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" just install
```

This builds a universal binary, codesigns it, and copies it to `~/.local/bin` (override with `INSTALL_DIR=/usr/local/bin`).

### Verify

```bash
scm --version
```

## First run — interactive menu

Run `scm` with no arguments to open the interactive main menu:

```
scm
```

You will see:

```
███████╗ ██████╗███╗   ███╗
██╔════╝██╔════╝████╗ ████║
███████╗██║     ██╔████╔██║
╚════██║██║     ██║╚██╔╝██║
███████║╚██████╗██║ ╚═╝ ██║
╚══════╝ ╚═════╝╚═╝     ╚═╝
Swift Cardano Multitool
```

Followed by an interactive list of all available commands. Use the arrow keys to move and Return to select a command. Each command opens a submenu with its specific options.

## First run — direct CLI

Every command and subcommand can also be invoked directly without the interactive menu:

```bash
# Show the chain tip
scm query tip

# Initialize a configuration file
scm config init

# Install cardano-node
scm install cardano-node

# Get help for any command
scm --help
scm query --help
scm transaction --help
```

## Typical first-time workflow

1. **Initialize a configuration file** so `scm` knows which network and node socket to use:
   ```bash
   scm config init
   ```
   The wizard will ask for your network, socket path, config directory, and preferred blockchain provider. It saves a config file at a path you choose.

2. **Export the config path** so all subsequent commands pick it up:
   ```bash
   export CARDANO_MULTITOOL_CONFIG=~/.config/scm/mainnet.json
   ```
   Add this to your shell profile (`~/.zshrc`, `~/.bashrc`) to make it permanent.

3. **Download network configuration files** if you haven't already set up a node:
   ```bash
   scm download configuration-files
   ```

4. **Start the node** (optional — if you want to run your own node):
   ```bash
   scm run node
   ```

5. **Query the chain tip** to confirm your node is running and in sync:
   ```bash
   scm query tip
   ```

## Scripting and automation

Set `CARDANO_MULTITOOL_SKIP_PROMPT=1` to suppress interactive confirmation prompts and make `scm` suitable for use in scripts:

```bash
export CARDANO_MULTITOOL_SKIP_PROMPT=1
scm query tip
```

See <doc:Configuration> for the full list of environment variables.
