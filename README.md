# TAPENET - deploy

![image](https://github.com/user-attachments/assets/5b1fa103-0814-4ed4-966d-c9cb1aafeb2f)

This repository contains everything you need to deploy a fully functioning **reference** TAPEDRIVE node — including archive, miner, and web services — using NGINX and the official `tapedrive-cli` binary releases from GitHub.

> [!WARNING]
> **This is an early reference implementation**. It is not intended for production use. Use at your own risk.
>
> **Only DEVNET is supported at this time.**

---

## 📦 Prerequisites

- **A remote linux server** (Ubuntu 24.04 recommended)
- Access via SSH (key-based)

The setup script can run a `source build` or download a `pre-built binary`. Binary releases are fetched automatically from [GitHub](https://github.com/tapedrive-io/tape/releases).

---

## 🚀 Deployment Steps

### 1. Clone this repo
```
    git clone https://github.com/spool-labs/deploy.git
    cd tape-deploy
```

### 2. Configure your server
```
    make configure
```

You will be prompted for:

- SSH address (e.g. `root@123.123.123.123`)
- Domain (e.g. `node.tapedrive.io`)
- Build method: **binary (recommended)** or source

This creates `tapedrive.config` for the Makefile.

### 3. Run the setup
```
    make setup
```

By default (binary build):

- Installs runtime deps (NGINX, Certbot)
- Downloads latest `tapedrive` binary from GitHub
- Renders and uploads systemd unit files
- Uploads or retrieves `deploy/miner.json`
- Configures NGINX and UFW

If you selected **source**, it will compile from source (may take a while).

> [!IMPORTANT]
> To pre-generate a `miner.json` identity:
>
>     solana-keygen new --outfile deploy/miner.json
>
> Without it, a new keypair will be generated on the remote and downloaded to `deploy/miner.json`.

### 4. Check logs
```
    make logs-tapemine
    make logs-tapearchive
    make logs-tapeweb
```

If you don't see any logs, you might need to reboot your machine. On some Linux distros (especially cloud images or custom setups), `journald` doesn't properly initialize persistent storage or attach to early services until after a reboot.

> [!IMPORTANT]
> **You will need to fund your miner with some SOL** to get started. You can do this by sending SOL to the address in ./deploy/miner.json.
>
> First, check the SOL address of your miner by running:
> ```bash
> solana address -k deploy/miner.json
> ```

>
> Then, fund your miner with some SOL using the Solana CLI or a wallet.

---

### 5. Restart services (if/whenever needed)

```bash
make deploy
```

This will restart all three tapedrive services on your configured server.

---

### 6. Upgrade the to latest version (if/whenever needed)

```bash
make upgrade
```

This will pull the latest version of tapedrive-cli from crates.io and restart the services.

---

### 7. Snapshot the archive (if needed)

```bash
make snapshot
```

Downloads a snapshot of the archive database to `./db_tapestore`.

---

## 🛠️ Troubleshooting

If issues arise:

    make logs-tapemine
    make logs-tapearchive
    make logs-tapeweb
    make ssh

**Health check:**

    curl -X POST http://<your_server>/api \
      -H 'Content-Type: application/json' \
      -d '{"jsonrpc":"2.0","id":1,"method":"getHealth","params":{}}'

**Get tape address:**

    curl -X POST http://<your_server>/api \
      -H 'Content-Type: application/json' \
      -d '{"jsonrpc":"2.0","id":1,"method":"getTapeAddress","params":{"tape_number":1}}'

See full RPC docs [here](https://docs.rs/tape-network/latest/tape_network/web/index.html).

---

## 📦 What’s Included

- `scripts/setup.sh` (source build)
- `scripts/setup-binary.sh` (binary build)
- `templates/` for service + nginx configs
- `deploy/` for rendered configs
- Makefile for end-to-end management

---

## 📦 Need Help?

Reach out to [@tapedrive_io](https://twitter.com/tapedrive_io) for support.
