.PHONY: help build up down logs status clean rebuild ssh-tunnel deploy

# Color output
BLUE=\033[0;34m
GREEN=\033[0;32m
YELLOW=\033[1;33m
NC=\033[0m # No Color

PROJECT_DIR := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))
VM_USER ?= user
VM_HOST ?= localhost
VM_PORT ?= 22

help: ## Show this help message
	@echo "$(BLUE)ConSEC Docker Deployment$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make deploy              # Full setup and start"
	@echo "  make up                  # Start containers"
	@echo "  make logs               # View all logs"
	@echo "  make ssh-tunnel VM_HOST=192.168.x.x  # Create SSH tunnel"

setup-env: ## Create .env file from template
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN)✓ Created .env$(NC)"; \
	else \
		echo "$(YELLOW)⚠ .env already exists$(NC)"; \
	fi

setup-dirs: ## Create required data directories
	@mkdir -p consec_data/{grafana,prometheus,suricata_logs,zeek_logs}
	@chmod 777 consec_data/*
	@chmod +x entrypoints/*.sh
	@echo "$(GREEN)✓ Directories created$(NC)"

build: setup-env setup-dirs ## Build Docker image
	@echo "$(BLUE)Building Docker image...$(NC)"
	docker build -t consec-base:latest .
	@echo "$(GREEN)✓ Build complete$(NC)"

up: setup-env setup-dirs ## Start containers
	@echo "$(BLUE)Starting ConSEC services...$(NC)"
	docker compose up -d
	@sleep 2
	@make status

down: ## Stop containers from running
	@echo "$(BLUE)Stopping ConSEC services...$(NC)"
	docker compose down
	@echo "$(GREEN)✓ Services stopped$(NC)"

logs: ## View logs for all services
	docker compose logs -f

logs-suricata: ## View Suricata logs
	docker compose logs -f suricata

logs-zeek: ## View Zeek logs
	docker compose logs -f zeek

logs-grafana: ## View Grafana logs
	docker compose logs -f grafana

logs-prometheus: ## View Prometheus logs
	docker compose logs -f prometheus

status: ## Show container status
	@echo "$(BLUE)Container Status:$(NC)"
	docker compose ps
	@echo ""
	@echo "$(GREEN)Access URLs:$(NC)"
	@echo "  Grafana:    http://localhost:3000 (admin/admin)"
	@echo "  Prometheus: http://localhost:9090"

stats: ## Show resource usage
	docker stats --no-stream

clean: ## Stop containers and remove volumes
	@echo "$(YELLOW)Removing all containers and volumes...$(NC)"
	docker compose down -v
	@echo "$(GREEN)✓ Cleaned$(NC)"

rebuild: clean build up ## Rebuild from scratch

restart: down up ## Restart containers

deploy: build up ## Full deployment (build + start)
	@echo ""
	@echo "$(GREEN)╔═════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║  ConSEC Deployment Complete! ✓      ║$(NC)"
	@echo "$(GREEN)╚═════════════════════════════════════╝$(NC)"
	@echo ""
	@make status

ssh-tunnel: ## Create SSH tunnel (requires VM_HOST=xxx VM_USER=xxx)
	@echo "$(BLUE)Creating SSH tunnel...$(NC)"
	@echo "Local Port 3000   → $(VM_HOST):3000 (Grafana)"
	@echo "Local Port 9090   → $(VM_HOST):9090 (Prometheus)"
	@echo ""
	@echo "$(YELLOW)SSH command:$(NC)"
	@echo "ssh -L 3000:localhost:3000 -L 9090:localhost:9090 -N $(VM_USER)@$(VM_HOST)"
	@echo ""
	@ssh -L 3000:localhost:3000 -L 9090:localhost:9090 -N $(VM_USER)@$(VM_HOST) || \
		(echo "$(YELLOW)SSH failed. Check host, user, and network connectivity.$(NC)" && exit 1)

shell-suricata: ## Open shell in Suricata container
	docker compose exec suricata /bin/bash

shell-zeek: ## Open shell in Zeek container
	docker compose exec zeek /bin/bash

shell-prometheus: ## Open shell in Prometheus container
	docker compose exec prometheus /bin/sh

shell-grafana: ## Open shell in Grafana container
	docker compose exec grafana /bin/bash

exec-suricata: ## Execute command in Suricata (usage: make exec-suricata CMD="command")
	docker compose exec suricata $(CMD)

test-connectivity: ## Test service connectivity
	@echo "$(BLUE)Testing service connectivity...$(NC)"
	@echo -n "Grafana:    "
	@curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/api/health || echo "Failed"
	@echo -n "Prometheus: "
	@curl -s -o /dev/null -w "%{http_code}\n" http://localhost:9090/-/healthy || echo "Failed"
	@echo "$(GREEN)✓ Connectivity test complete$(NC)"

validate: ## Validate docker compose configuration
	@echo "$(BLUE)Validating configuration...$(NC)"
	docker compose config > /dev/null && echo "$(GREEN)✓ Configuration valid$(NC)" || echo "$(RED)✗ Configuration invalid$(NC)"

version: ## Show versions
	@echo "$(BLUE)Component Versions:$(NC)"
	@docker --version
	@docker compose --version
	@echo "$(GREEN)Image$(NC): $(shell docker images consec-base -q | head -1 || echo 'Not built')"

prune: ## Clean up unused Docker resources
	@echo "$(YELLOW)Pruning Docker resources...$(NC)"
	docker system prune -f
	@echo "$(GREEN)✓ Pruned$(NC)"

docs: ## Show available documentation
	@echo "$(BLUE)ConSEC Documentation:$(NC)"
	@ls -1 *.md
	@echo ""
	@echo "$(GREEN)Quick Start:$(NC) README.md"
	@echo "$(GREEN)SSH Tunnels:$(NC) SSH-PORT-FORWARDING.md"
	@echo "$(GREEN)Quick Ref:$(NC) QUICK-REFERENCE.md"

.DEFAULT_GOAL := help
