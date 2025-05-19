# TAPEDRIVE - DEPLOY

This repository contains everything you need to deploy a fully functioning reference TAPEDRIVE node — including archive, miner, and web services — using NGINX, and the official `tapedrive-cli` published on crates.io. 

This script is designed to be run on a remote server, and it will install all necessary dependencies, configure systemd services, and set up NGINX for you.

You can run all three roles (archive, mine, and web) on the same machine, and setup only takes a few minutes.

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
- Solana cluster to use (`devnet`, `testnet`, or `mainnet`)
- A name for your miner

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
- Optionally upload or retrieve `miner.json` identity file
- Configure NGINX and UFW

---

### 4. Check the logs (if needed)

```bash
make logs-tapemine
make logs-tapearchive
make logs-tapeweb
```

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

## 🧠 What’s Included

- `setup.sh` installs system packages and Rust
- `templates/` contains templated service + nginx configs
- `deploy/` is where rendered configs live before upload
- `Makefile` manages everything with simple commands

There are a few more commands available in the Makefile, including:
- `make ssh` to SSH into your server quickly
- `make setup-firewall` to configure UFW
- `make certbot` to configure Certbot for HTTPS
- etc... 

Check the Makefile for all available commands.

---

## 🛠 Requirements

- A remote Ubuntu server (24.04 recommended)
- DNS configured for your domain if you want to serve HTTPS
- Access via SSH (password or key-based)

---

## 🧪 Example Commands

```bash
make configure
make setup
make deploy
make logs-tapearchive
```

---

## 📦 Need Help?

Reach out to [@tapedrive_io](https://twitter.com/tapedrive_io) for support.
