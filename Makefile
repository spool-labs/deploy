-include tapedrive.config

APP_DIR=~/apps/tapedrive
BIN_NAME=tapedrive
SERVICES=tapearchive tapemine tapeweb
DEPLOY_DIR=deploy
TEMPLATES_DIR=templates

.PHONY: render-configs ssh logs-% certbot snapshot \
        get-binary build-binary build-darwin \
        setup setup-source setup-binary common-post-setup \
        setup-firewall deploy deploy-services \
        upgrade configure require-config install

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
ifndef BUILD_METHOD
	$(error Missing BUILD_METHOD. Please run `make configure`)
endif

render-configs: require-config
	@mkdir -p $(DEPLOY_DIR)
	@sed -e 's|{{DOMAIN}}|$(DOMAIN)|g' \
	    $(TEMPLATES_DIR)/nginx.conf.template \
	  > $(DEPLOY_DIR)/nginx.conf
	@sed -e 's|{{CLUSTER}}|$(CLUSTER)|g' \
	    $(TEMPLATES_DIR)/tapeweb.service.template \
	  > $(DEPLOY_DIR)/tapeweb.service
	@sed -e 's|{{CLUSTER}}|$(CLUSTER)|g' \
	    $(TEMPLATES_DIR)/tapearchive.service.template \
	  > $(DEPLOY_DIR)/tapearchive.service
	@sed -e 's|{{CLUSTER}}|$(CLUSTER)|g' \
	    $(TEMPLATES_DIR)/tapemine.service.template \
	  > $(DEPLOY_DIR)/tapemine.service

ssh: require-config
	ssh $(REMOTE)

logs-%: require-config
	ssh $(REMOTE) 'journalctl -fu $*'

certbot: require-config
	ssh $(REMOTE) 'certbot --nginx -d $(DOMAIN)'

snapshot: require-config
	scp -r $(REMOTE):~/apps/tapedrive/db_tapestore ./db_tapestore

get-binary:
	scp $(REMOTE):~/build/tapedrive/$(BIN_NAME)-linux-musl.tar.gz ./$(BIN_NAME)-linux-musl.tar.gz

build-binary:
	@scp ./scripts/build.sh $(REMOTE):~
	ssh $(REMOTE) 'bash ~/build.sh'

common-post-setup:
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

	@# swap out default nginx site, copy our new config, and reload
	ssh $(REMOTE) 'rm -f /etc/nginx/sites-enabled/default && nginx -t && systemctl reload nginx'
	scp $(DEPLOY_DIR)/nginx.conf $(REMOTE):/etc/nginx/sites-available/tapedrive
	ssh $(REMOTE) 'ln -sf /etc/nginx/sites-available/tapedrive /etc/nginx/sites-enabled/tapedrive && nginx -t && systemctl reload nginx'

setup: render-configs
ifeq ($(BUILD_METHOD),source)
	@$(MAKE) setup-source
else
	@$(MAKE) setup-binary
endif

setup-source:
	scp ./scripts/setup-source.sh $(REMOTE):~
	ssh $(REMOTE) 'bash ~/setup-source.sh'
	$(MAKE) common-post-setup

setup-binary:
	scp ./scripts/setup-binary.sh $(REMOTE):~
	ssh $(REMOTE) 'bash ~/setup-binary.sh'
	$(MAKE) common-post-setup

.PHONY: install
install:
	scp ./scripts/install.sh $(REMOTE):~
	ssh $(REMOTE) 'bash ~/install.sh'

setup-firewall:
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
	@read -p "Enter your SSH remote (e.g. root@0.0.0.0): " remote && \
	 read -p "Enter the domain to use (e.g. example.com): " domain && \
	 read -p "Enter the Solana cluster (l, m, d, t, or RPC URL): " cluster && \
	 read -p "Build from source? [y/N]: " build_choice && \
	 if [ "$$build_choice" = "y" ] || [ "$$build_choice" = "Y" ]; then \
	   method=source; \
	 else \
	   method=binary; \
	 fi && \
	 echo "REMOTE = $$remote"     > tapedrive.config && \
	 echo "DOMAIN = $$domain"   >> tapedrive.config && \
	 echo "CLUSTER = $$cluster" >> tapedrive.config && \
	 echo "BUILD_METHOD = $$method" >> tapedrive.config && \
	 echo "" && echo "✅ tapedrive.config created with BUILD_METHOD=$$method." && \
	 echo "" && echo "🔧 Run 'make setup' to set up the server." && echo "" 
