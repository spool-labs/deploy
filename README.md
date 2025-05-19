# TAPENET - deploy

![image](https://github.com/user-attachments/assets/5b1fa103-0814-4ed4-966d-c9cb1aafeb2f)


This repository contains everything you need to deploy a fully functioning **reference** TAPEDRIVE node — including archive, miner, and web services — using NGINX, and the official `tapedrive-cli` published on crates.io. 

This script is designed to be run on against a remote server, and it will install all necessary dependencies, configure systemd services, and set up NGINX for you.

You can run all three roles (archive, mine, and web) on the same machine, and setup only takes a few minutes.

> [!WARNING]
> **This is an early reference implementation**. It is not intended for production use. Use at your own risk. 
>
> **Only DEVNET is supported at this time.**

---

## 📦 Prerequisites

- **A remote Ubuntu server** (24.04 recommended, but 22.04 should work too)
- Access via SSH (key-based)

This script has been tested against AWS, DigitalOcean, and a few other providers. It should work on any fresh Ubuntu server, but if you run into issues, please open an issue. 

The script compiles everything from source, so it may take a while to run. Binary releases will come soon.

---

## 🚀 Deployment Steps

### 1. Clone this repo on your local machine

```bash
git clone https://github.com/tapedrive-io/tape-deploy.git
cd tape-deploy
```

---

### 2. Configure your server info

Create a config file from the example:

```bash
make configure
```

This will prompt you for:

- SSH address to your server (e.g. `root@123.123.123.123`)
- Domain you plan to serve from (e.g. `node.tapedrive.io`)

This will create a `tapedrive.config` file used by the Makefile.

---

### 3. Run the setup

```bash
make setup
```

This will:

- Install all necessary dependencies (Rust, NGINX, Certbot)
- Install `tapedrive-cli` from crates.io
- Render config files from templates
- Upload and enable systemd services
- Optionally upload or retrieve `./deploy/miner.json` identity file
- Configure NGINX and UFW

> [!IMPORTANT]
> You can pre-create a `miner.json` file using the `solana-keygen` command. This will allow you to use a specific identity for your miner. If you don't have a `miner.json` file, the script will create one for you. It will be placed into the `./deploy/` directory automatically if everithing goes well. Check the logs if you need to troubleshoot.

---

### 4. Check the logs (if needed)

```bash
make logs-tapemine
make logs-tapearchive
make logs-tapeweb
```

> [!IMPORTANT]
> **You will need to fund your miner with some SOL** to get started. You can do this by sending SOL to the address in `./deploy/miner.json`.
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

This will pull the latest version of `tapedrive-cli` from crates.io and restart the services.

---

### 7. Snapshot the archive (if needed)

```bash
make snapshot
```

This will create a snapshot of the archive node and download it to your local machine. This is useful for backup purposes or if you want to run a local archive node.

--- 

## 🛠️ Troubleshooting

If you run into issues, check the logs for each service:

```bash
make logs-tapemine
make logs-tapearchive
make logs-tapeweb
```

If you need to SSH into your server, you can do so with:

```bash
make ssh
```

If you did everything correctly, you should see RPC responses from your server for these commands:

**Health check:**
```bash
curl -X POST http://<your_server>/api \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'

> {"jsonrpc":"2.0","result":{"drift":0,"last_processed_slot":381995763},"id":5}
```

**Get tape address:**
```bash
curl -X POST http://<your_server>/api \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getTapeAddress","params":{"tape_number":1}}'

> {"jsonrpc":"2.0","result":"BEB4TSSg2k2jKR8rnSKFeaEvNdxKaMv3EQCVBAUaEUPM","id":1}
```

You can see a full list of RPC endpoints [here](https://docs.rs/tape-network/latest/tape_network/web/index.html).

---

## 🧠 What’s Included

- `setup.sh` installs system packages and Rust
- `templates/` contains templated service + nginx configs
- `deploy/` is where rendered configs live before upload
- `Makefile` manages everything with simple commands

Check the Makefile for all available commands.


---

## 📦 Need Help?

Reach out to [@tapedrive_io](https://twitter.com/tapedrive_io) for support.
