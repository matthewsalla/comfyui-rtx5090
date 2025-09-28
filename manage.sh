#!/bin/bash

# Management script for ComfyUI + Stable Diffusion stack
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       Start all services"
    echo "  stop        Stop all services"
    echo "  restart     Restart all services"
    echo "  status      Show status of all services"
    echo "  logs        Show logs of all services"
    echo "  build       Build or rebuild services"
    echo "  update      Update ComfyUI and Stable Diffusion WebUI"
    echo "  setup       Run initial setup (build wheels, create directories)"
    echo "  help        Show this help message"
    echo ""
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
}

start_services() {
    print_status "Starting services..."
    docker-compose up -d
    print_success "Services started!"
    print_status "ComfyUI: http://localhost:8188"
    print_status "Stable Diffusion WebUI: http://localhost:7860"
}

stop_services() {
    print_status "Stopping services..."
    docker-compose down
    print_success "Services stopped!"
}

restart_services() {
    print_status "Restarting services..."
    docker-compose restart
    print_success "Services restarted!"
}

show_status() {
    print_status "Service status:"
    docker-compose ps
}

show_logs() {
    print_status "Service logs:"
    docker-compose logs -f
}

build_services() {
    print_status "Building services..."
    docker-compose build --no-cache
    print_success "Services built!"
}

update_services() {
    print_status "Updating services..."
    docker-compose exec comfyui bash -c "cd /workspace/comfyui && git pull"
    docker-compose exec stable-diffusion bash -c "cd /workspace/webui && git pull"
    print_success "Services updated!"
}

setup() {
    print_status "Running initial setup..."
    
    # Check if build-wheels.sh exists and is executable
    if [ -f "build-wheels.sh" ] && [ -x "build-wheels.sh" ]; then
        print_status "Building wheels..."
        ./build-wheels.sh
    else
        print_warning "build-wheels.sh not found or not executable. Skipping wheel building."
    fi
    
    print_success "Setup complete!"
}

# Main script
main() {
    check_docker
    
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    case $1 in
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        build)
            build_services
            ;;
        update)
            update_services
            ;;
        setup)
            setup
            ;;
        help)
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"