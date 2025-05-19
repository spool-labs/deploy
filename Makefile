# Load deployment config
-include tapedrive.config

APP_DIR=~/apps/tapedrive
BIN_NAME=tapedrive
SERVICES=tapearchive tapemine tapeweb
DEPLOY_DIR=deploy
TEMPLATES_DIR=templates

.PHONY: render-configs ssh deploy setup deploy-services logs-% certbot snapshot configure

require-config:
ifndef REMOTE
	$(error Missing REMOTE. Please run `make configure`)
endif
ifndef DOMAIN
	$(error Missing DOMAIN. Please run `make configure`)
endif
ifndef CLUSTER
	$(error Missing CLUSTER. Please run `make configure`)
endif

render-configs: require-config
	@mkdir -p $(DEPLOY_DIR)
	sed \
	  -e 's|{{DOMAIN}}|$(DOMAIN)|g' \
	  $(TEMPLATES_DIR)/nginx.conf.template > $(DEPLOY_DIR)/nginx.conf
	sed \
	  -e 's|{{CLUSTER}}|$(CLUSTER)|g' \
	  $(TEMPLATES_DIR)/tapeweb.service.template > $(DEPLOY_DIR)/tapeweb.service
	sed \
	  -e 's|{{CLUSTER}}|$(CLUSTER)|g' \
	  $(TEMPLATES_DIR)/tapearchive.service.template > $(DEPLOY_DIR)/tapearchive.service
	sed \
	  -e 's|{{CLUSTER}}|$(CLUSTER)|g' \
	  $(TEMPLATES_DIR)/tapemine.service.template > $(DEPLOY_DIR)/tapemine.service

ssh: require-config
	ssh $(REMOTE)

logs-%: require-config
	ssh $(REMOTE) 'journalctl -fu $*'

certbot: require-config
	ssh $(REMOTE) 'certbot --nginx -d $(DOMAIN)'

snapshot: require-config
	scp -r $(REMOTE):~/apps/tapedrive/db_tapestore ./db_tapestore

setup: render-configs
	scp setup.sh $(REMOTE):~
	ssh $(REMOTE) 'bash ~/setup.sh'

	@if [ -f deploy/miner.json ]; then \
	  echo "📤 Uploading existing miner.json to remote..."; \
	  scp deploy/miner.json $(REMOTE):~/.config/solana/id.json; \
	else \
	  echo "ℹ️  No local miner.json found. Will fetch it after remote miner starts."; \
	fi

	$(MAKE) deploy-services

	@if [ ! -f deploy/miner.json ]; then \
	  echo "📥 Downloading miner.json from remote now that service has started..."; \
	  scp $(REMOTE):~/.config/solana/id.json deploy/miner.json || \
	    echo "⚠️ Warning: miner.json not found on remote either."; \
	fi

	scp $(DEPLOY_DIR)/nginx.conf $(REMOTE):/etc/nginx/sites-available/tapedrive
	ssh $(REMOTE) 'ln -sf /etc/nginx/sites-available/tapedrive /etc/nginx/sites-enabled/tapedrive && nginx -t && systemctl reload nginx'
	ssh $(REMOTE) 'ufw allow 80/tcp && ufw allow 443/tcp && ufw allow 22/tcp && ufw deny 3000/tcp && ufw reload'

deploy: require-config
	ssh $(REMOTE) 'systemctl restart $(SERVICES)'

deploy-services: render-configs require-config
	scp $(DEPLOY_DIR)/{tapearchive.service,tapemine.service,tapeweb.service} \
	  $(REMOTE):/etc/systemd/system/
	ssh $(REMOTE) '\
	  systemctl daemon-reload && \
	  systemctl enable --now $(SERVICES) \
	'

upgrade:
	@echo "🔄 Upgrading tapedrive-cli on remote..."
	ssh $(REMOTE) 'source ~/.cargo/env && cargo install tapedrive-cli --force && ln -sf ~/.cargo/bin/tapedrive ~/apps/tapedrive/tapedrive'
	@echo "Restarting services..."
	ssh $(REMOTE) 'systemctl restart $(SERVICES)'


configure:
	@echo "🔧 Setting up tapedrive.config interactively..."
	@read -p "Enter your SSH remote (e.g. root@123.123.123.123): " remote && \
	 read -p "Enter the domain to use for the mining node: " domain && \
	 read -p "Enter the Solana cluster to mine on (devnet, mainnet, etc): " cluster && \
	 echo "REMOTE = $$remote" > tapedrive.config && \
	 echo "DOMAIN = $$domain" >> tapedrive.config && \
	 echo "CLUSTER = $$cluster" >> tapedrive.config && \
	 echo "" && echo "✅ tapedrive.config created successfully."
