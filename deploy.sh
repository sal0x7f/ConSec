#!/bin/bash
# ConSEC Deployment & Build Script
# For use on VM or local machine running Docker

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${PROJECT_DIR}/docker compose.yml"
ENV_FILE="${PROJECT_DIR}/.env"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v docker compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    log_info "✓ Docker and Docker Compose are installed"
}

# Setup environment
setup_environment() {
    log_info "Setting up environment..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_warn ".env not found, creating from .env.example"
        cp "${PROJECT_DIR}/.env.example" "$ENV_FILE"
        log_info "Created .env - please review and customize if needed"
    fi
    
    # Create data directories
    mkdir -p "${PROJECT_DIR}/consec_data"/{grafana,prometheus,suricata_logs,zeek_logs}
    chmod 777 "${PROJECT_DIR}/consec_data"/*
    
    # Make entrypoint scripts executable
    chmod +x "${PROJECT_DIR}/entrypoints"/*.sh
    
    log_info "✓ Environment setup complete"
}

# Build custom image (optionaal)
build_image() {
    log_info "Building custom ConSEC Docker image..."
    docker build -t consec-base:latest -f "${PROJECT_DIR}/Dockerfile" "${PROJECT_DIR}"
    log_info "✓ Image build complete: consec-base:latest"
}

# Start services
start_services() {
    log_info "Starting ConSEC services..."
    cd "$PROJECT_DIR"
    docker compose -f "$COMPOSE_FILE" up -d
    log_info "✓ Services started"
    
    # Wait for services to be healthy
    log_info "Waiting for services to be ready..."
    sleep 5
    
    # Show status
    docker compose -f "$COMPOSE_FILE" ps
}

# Show access information
show_access_info() {
    log_info "ConSEC Services are running!"
    echo ""
    echo "════════════════════════════════════════════════════"
    echo "Service Access Information"
    echo "════════════════════════════════════════════════════"
    echo ""
    echo "📊 Grafana (Dashboards)"
    echo "   URL: http://localhost:3000"
    echo "   Default Login: admin/admin"
    echo ""
    echo "📈 Prometheus (Metrics)"
    echo "   URL: http://localhost:9090"
    echo ""
    echo "🔐 Suricata (IDS)"
    echo "   Logs: ${PROJECT_DIR}/consec_data/suricata_logs/"
    echo ""
    echo "🔍 Zeek (Network Analysis)"
    echo "   Logs: ${PROJECT_DIR}/consec_data/zeek_logs/"
    echo ""
    echo "════════════════════════════════════════════════════"
    echo ""
    echo "For SSH Port Forwarding Setup:"
    echo "  See SSH-PORT-FORWARDING.md for detailed instructions"
    echo ""
    echo "Container Status:"
    docker compose -f "$COMPOSE_FILE" ps
}

# Cleanup
cleanup() {
    log_info "Stopping all ConSEC services..."
    docker compose -f "$COMPOSE_FILE" down
    log_info "✓ Services stopped"
}

# Main menu
show_menu() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║    ConSEC Deployment Menu              ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "1) Full Setup (Build + Start)"
    echo "2) Start Services"
    echo "3) Stop Services"
    echo "4) View Logs"
    echo "5) Check Status"
    echo "6) Build Image Only"
    echo "7) Clean Up & Stop"
    echo "0) Exit"
    echo ""
}

# Main script
main() {
    if [[ $# -eq 0 ]]; then
        show_menu
        read -p "Select option: " choice
    else
        choice=$1
    fi
    
    case $choice in
        1)
            check_prerequisites
            setup_environment
            build_image
            start_services
            show_access_info
            ;;
        2)
            check_prerequisites
            setup_environment
            start_services
            show_access_info
            ;;
        3)
            cleanup
            ;;
        4)
            cd "$PROJECT_DIR"
            docker compose -f "$COMPOSE_FILE" logs -f
            ;;
        5)
            cd "$PROJECT_DIR"
            docker compose -f "$COMPOSE_FILE" ps
            ;;
        6)
            check_prerequisites
            build_image
            ;;
        7)
            cleanup
            log_info "Removing volumes..."
            docker compose -f "$COMPOSE_FILE" down -v
            ;;
        0)
            log_info "Exiting"
            exit 0
            ;;
        *)
            log_error "Invalid option"
            show_menu
            ;;
    esac
}

main "$@"
