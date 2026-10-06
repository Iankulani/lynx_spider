# ============================================
# LYNX-SPIDER-V1 - Makefile
# Author: Ian Carter Kulani
# ============================================

.PHONY: help install test lint clean build run docker-build docker-run docker-stop deploy

# Variables
APP_NAME = lynx-spider-v1
VERSION = 1.0.0
DOCKER_IMAGE = $(APP_NAME):$(VERSION)
DOCKER_IMAGE_LATEST = $(APP_NAME):latest
PYTHON = python3
PIP = pip3
VENV = venv

# Colors
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
CYAN = \033[0;36m
NC = \033[0m

help: ## Show this help message
	@echo "$(CYAN)🕷️  LYNX-SPIDER-V1 - Makefile$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

# ============ INSTALLATION ============
install: ## Install dependencies
	@echo "$(CYAN)📦 Installing dependencies...$(NC)"
	$(PYTHON) -m venv $(VENV)
	. $(VENV)/bin/activate && $(PIP) install --upgrade pip setuptools wheel
	. $(VENV)/bin/activate && $(PIP) install -r requirements.txt
	@echo "$(GREEN)✅ Dependencies installed$(NC)"

install-dev: ## Install development dependencies
	@echo "$(CYAN)📦 Installing development dependencies...$(NC)"
	. $(VENV)/bin/activate && $(PIP) install -r requirements-dev.txt
	@echo "$(GREEN)✅ Development dependencies installed$(NC)"

# ============ TESTING ============
test: ## Run tests
	@echo "$(CYAN)🧪 Running tests...$(NC)"
	. $(VENV)/bin/activate && python test-commands.py --all --verbose
	@echo "$(GREEN)✅ Tests complete$(NC)"

test-unit: ## Run unit tests
	@echo "$(CYAN)🧪 Running unit tests...$(NC)"
	. $(VENV)/bin/activate && pytest test-commands.py -v --cov=lynx_spider

test-quick: ## Run quick tests
	@echo "$(CYAN)🧪 Running quick tests...$(NC)"
	. $(VENV)/bin/activate && python test-commands.py --system-only

# ============ LINTING ============
lint: ## Run linters
	@echo "$(CYAN)🔍 Running linters...$(NC)"
	. $(VENV)/bin/activate && flake8 lynx_spider.py --max-line-length=120 --ignore=E501,W503,E722
	. $(VENV)/bin/activate && pylint lynx_spider.py --disable=all --enable=E || true
	@echo "$(GREEN)✅ Linting complete$(NC)"

format: ## Format code
	@echo "$(CYAN)🎨 Formatting code...$(NC)"
	. $(VENV)/bin/activate && black lynx_spider.py
	. $(VENV)/bin/activate && isort lynx_spider.py
	@echo "$(GREEN)✅ Formatting complete$(NC)"

# ============ RUNNING ============
run: ## Run the application
	@echo "$(CYAN)🚀 Running LYNX-SPIDER-V1...$(NC)"
	. $(VENV)/bin/activate && $(PYTHON) lynx_spider.py

# ============ DOCKER ============
docker-build: ## Build Docker image
	@echo "$(CYAN)🐳 Building Docker image...$(NC)"
	docker build -t $(DOCKER_IMAGE) -t $(DOCKER_IMAGE_LATEST) -f Dockerfile .
	@echo "$(GREEN)✅ Docker image built$(NC)"

docker-build-alpine: ## Build Alpine Docker image
	@echo "$(CYAN)🐳 Building Alpine Docker image...$(NC)"
	docker build -t $(DOCKER_IMAGE)-alpine -t $(DOCKER_IMAGE_LATEST)-alpine -f Dockerfile.alpine .
	@echo "$(GREEN)✅ Alpine Docker image built$(NC)"

docker-run: ## Run Docker container
	@echo "$(CYAN)🐳 Running Docker container...$(NC)"
	docker run -it --rm \
		--name $(APP_NAME) \
		--cap-add=NET_ADMIN \
		--cap-add=NET_RAW \
		-p 5000:5000 \
		-p 8080:8080 \
		$(DOCKER_IMAGE_LATEST)

docker-up: ## Start with docker-compose
	@echo "$(CYAN)🐳 Starting docker-compose...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)✅ Services started$(NC)"

docker-down: ## Stop docker-compose
	@echo "$(CYAN)🐳 Stopping docker-compose...$(NC)"
	docker-compose down
	@echo "$(GREEN)✅ Services stopped$(NC)"

docker-logs: ## Show Docker logs
	docker-compose logs -f lynx-spider

docker-clean: ## Clean Docker resources
	@echo "$(CYAN)🧹 Cleaning Docker resources...$(NC)"
	docker-compose down -v --remove-orphans
	docker system prune -f
	@echo "$(GREEN)✅ Cleanup complete$(NC)"

# ============ CLEANUP ============
clean: ## Clean build artifacts
	@echo "$(CYAN)🧹 Cleaning...$(NC)"
	rm -rf $(VENV)
	rm -rf __pycache__
	rm -rf .pytest_cache
	rm -rf htmlcov
	rm -rf .coverage
	rm -rf *.egg-info
	rm -rf build dist
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	@echo "$(GREEN)✅ Cleanup complete$(NC)"

clean-data: ## Clean application data
	@echo "$(RED)⚠️  Cleaning application data...$(NC)"
	rm -rf .lynx_spider
	rm -rf lynx_spider_reports
	rm -rf temp
	@echo "$(GREEN)✅ Data cleaned$(NC)"

# ============ DEPLOYMENT ============
deploy: ## Deploy to production
	@echo "$(CYAN)🚀 Deploying...$(NC)"
	./scripts/deploy.sh production

deploy-staging: ## Deploy to staging
	@echo "$(CYAN)🚀 Deploying to staging...$(NC)"
	./scripts/deploy.sh staging

# ============ UTILITIES ============
version: ## Show version
	@echo "$(APP_NAME) v$(VERSION)"

status: ## Show project status
	@echo "$(CYAN)📊 Project Status$(NC)"
	@echo "  Name: $(APP_NAME)"
	@echo "  Version: $(VERSION)"
	@echo "  Python: $$($(PYTHON) --version)"
	@echo "  Docker: $$(docker --version 2>/dev/null || echo 'Not installed')"
	@echo ""

init: ## Initialize project
	@echo "$(CYAN)🔧 Initializing project...$(NC)"
	mkdir -p .lynx_spider/{payloads,workspaces,scans,reports}
	mkdir -p lynx_spider_reports
	mkdir -p config/certs
	@echo "$(GREEN)✅ Project initialized$(NC)"

backup: ## Backup application data
	@echo "$(CYAN)💾 Creating backup...$(NC)"
	tar -czf backup_$$(date +%Y%m%d_%H%M%S).tar.gz .lynx_spider lynx_spider_reports
	@echo "$(GREEN)✅ Backup created$(NC)"

# ============ DEFAULT ============
.DEFAULT_GOAL := help
