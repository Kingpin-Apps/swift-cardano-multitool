# Ping

Ping cardano-node relays, or read a node's tip or the protocol versions it supports.

## Overview

The `ping` command talks to a node directly over the Ouroboros network protocol, the same way `cardano-cli ping` does. It needs no API key, and no local node unless you point it at one.

```bash
scm ping <node>... [--mode ping|tip|query] [options]
scm ping --help
```

Each `<node>` is either:

- **A relay**, as `host:port`, `[ipv6]:port`, or a bare host (port 3001). It is reached over node-to-node (TCP).
- **A local node's socket**, as a path — anything containing a `/`, such as `./node.socket` or `~/cardano/db/node.socket`. It is reached over node-to-client.

You can give several nodes at once; each is checked in turn.

## Modes

### ping

The default. Connects once and shows the TCP connect and handshake times, then sends `--count` keep-alives over that connection and times each round trip. Relays only, because keep-alive is a node-to-node protocol.

```bash
scm ping backbone.cardano.iog.io:3001
scm ping relay1:3001 [2001:db8::1]:3001 --count 10 --interval 0.5
```

```
Pinging backbone.cardano.iog.io:3001 (magic 764824073)
  connected: tcp 146.09 ms, handshake 137.9 ms, NtN v15
  seq=1 time=137.71 ms
  seq=2 time=140.84 ms
  seq=3 time=139.51 ms
  seq=4 time=138.45 ms
  4 sent, 4 received, 0% lost; min/avg/max = 137.71/139.13/140.84 ms
```

If a keep-alive fails, `scm` reconnects before the next one and shows the new handshake time.

### tip

Reads the node's current chain tip (slot, block number and block hash) over chain-sync.

```bash
scm ping backbone.cardano.iog.io:3001 --mode tip
scm ping ~/cardano/db/node.socket --mode tip
```

A node that is still syncing reports its own tip, not the network's. Compare it with a relay's tip to see how far behind it is.

### query

Lists every protocol version the node supports, highest first, with its network magic. Relays also show their diffusion mode and peer sharing, and versions from v16 their Peras flag.

```bash
scm ping preview-node.play.dev.cardano.org --mode query --network-magic 2
```

```
Versions of preview-node.play.dev.cardano.org:3001 (magic 2)
  NtN v15  magic 2, InitiatorAndResponder, peer sharing on
  NtN v14  magic 2, InitiatorAndResponder, peer sharing on
```

Node-to-client versions are shown as plain numbers (NtC v23), as `cardano-cli` shows them.

## Options

| Option | Description |
|--------|-------------|
| `--mode` | `ping` (default), `tip`, or `query`. |
| `-c`, `--count` | Keep-alives to send to each node in ping mode. Default 4. |
| `-i`, `--interval` | Seconds between keep-alives in ping mode. Default 1. |
| `-m`, `--network-magic` | Network magic for the handshake. Defaults to the network in your scm config, or mainnet when there is no config. |
| `-t`, `--timeout` | Seconds to wait for the connect and for each answer after the handshake. Default 10. |
| `--handshake-timeout` | Seconds to wait for the handshake. Default 30. |
| `-j`, `--json` | Machine-readable output. |

## Slow relays

A busy cardano-node delays new inbound connections once it is past its accepted-connections limit. The relay then accepts the TCP connection at once but takes many seconds to answer the handshake. `scm` times the two steps apart and gives the handshake its own, longer timeout:

```
Pinging r1.wavepool.digital:3001 (magic 764824073)
  connected: tcp 111.02 ms, handshake 8966.81 ms, NtN v15
  seq=1 time=52.43 ms
```

If even 30 s is not enough, the error says so and suggests a longer `--handshake-timeout`. When a check fails, the error names the step:

| Error | Meaning |
|-------|---------|
| `refused the connection` | Nothing is listening on that port (or socket). |
| `No answer … within 10s` | The host never accepted the connection: down, firewalled, or the wrong address. |
| `closed it during the handshake` | Something accepted the connection and then hung up; it may not be a cardano-node. |
| `did not answer the handshake within 30s` | The connection worked but the node is too busy, or too far behind, to answer in time. |

## Notes

- The handshake must use the node's network magic. If it doesn't, the error names the node's magic, for example `network magic mismatch: the node is on magic 2. Pass --network-magic 2.`
- `scm ping` exits with a non-zero status when a node does not answer at all, so it works as a health check in scripts and monitoring.
- Relays are contacted as `InitiatorOnly`, because `scm` only asks questions and serves nothing back.
- On macOS a Unix socket path must be shorter than 104 characters, a limit of the operating system.
- Run without arguments in a terminal, `scm ping` asks for the mode and the node.
