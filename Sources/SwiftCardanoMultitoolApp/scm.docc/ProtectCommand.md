# Protect

Encrypt and decrypt sensitive files.

## Overview

The `protect` command encrypts and decrypts files using a password-based scheme. It is designed to protect sensitive Cardano key files (`.skey`) and configuration files at rest.

```bash
scm protect <subcommand> [options]
scm protect --help
```

## Subcommands

### `encrypt`

Encrypt a file with a password. The original file is replaced by an encrypted version.

```bash
scm protect encrypt --file payment.skey
```

The wizard prompts for a password (and a confirmation) unless `CARDANO_MULTITOOL_DECRYPT_PASSWORD` is set in the environment.

**Options:**

| Option | Description |
|--------|-------------|
| `--file` | Path to the file to encrypt |
| `--out-file` | Write the encrypted file to a different path (optional — defaults to overwriting in place) |

### `decrypt`

Decrypt a file that was previously encrypted with `scm protect encrypt`.

```bash
scm protect decrypt --file payment.skey.enc
```

**Options:**

| Option | Description |
|--------|-------------|
| `--file` | Path to the encrypted file |
| `--out-file` | Write the decrypted file to a different path (optional) |

**Pre-supplying the password in scripts:**

```bash
export CARDANO_MULTITOOL_DECRYPT_PASSWORD="your-password"
scm protect decrypt --file payment.skey.enc
```

## Recommended workflow for key protection

1. Generate keys with `scm generate`.
2. Immediately encrypt private key files:
   ```bash
   scm protect encrypt --file payment.skey
   scm protect encrypt --file stake.skey
   scm protect encrypt --file node.skey
   ```
3. Store the encrypted files. Decrypt only when signing — decrypt in memory and shred the plaintext afterwards if possible.

## Notes

- Encryption uses a strong password-based key derivation function. Choose a long, random passphrase.
- There is no key recovery mechanism — if the password is lost, the encrypted file cannot be recovered. Store your password in a secure password manager.
- The `CARDANO_MULTITOOL_DECRYPT_PASSWORD` environment variable allows scripted decryption without interactive prompts. Exercise caution when using this in shell scripts to avoid leaking the password in process listings or shell history.
