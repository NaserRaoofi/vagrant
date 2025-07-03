#!/bin/bash

# Simple Vagrant Infrastructure Management Script
# Essential utilities for the multi-VM infrastructure

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
echo_success() { echo -e "${GREEN}✅ $1${NC}"; }
echo_error() { echo -e "${RED}❌ $1${NC}"; }

# Show help
show_help() {
    echo "Vagrant Infrastructure Management"
    echo ""
    echo "Standard Vagrant commands (recommended):"
    echo "  vagrant up              # Start all VMs (auto-provisions with Ansible)"
    echo "  vagrant status          # Show VM status"
    echo "  vagrant ssh <vm>        # SSH into specific VM (lb, web1, web2, db, monitor)"
    echo "  vagrant halt            # Stop all VMs"
    echo "  vagrant destroy         # Destroy all VMs"
    echo "  vagrant provision       # Re-run Ansible provisioning"
    echo ""
    echo "Additional utilities (this script):"
    echo "  $0 test                 # Test all services"
    echo "  $0 endpoints            # Show service URLs"
    echo "  $0 db-status            # Check database status"
    echo "  $0 logs <vm> <service>  # View service logs (e.g., logs web1 apache2)"
    echo "  $0 ssh <vm>             # SSH to VM (alternative to vagrant ssh)"
    echo ""
    echo "SSH Examples:"
    echo "  vagrant ssh lb          # SSH to Load Balancer (recommended)"
    echo "  vagrant ssh web1        # SSH to Web Server 1"
    echo "  vagrant ssh db          # SSH to Database Server"
    echo "  $0 ssh lb               # Alternative SSH method"
    echo ""
}

# Test all endpoints
test_endpoints() {
    echo_info "Testing service endpoints..."
    
    echo "🔧 Load Balancer (http://localhost:8080):"
    curl -s -o /dev/null -w "  Status: %{http_code}\n" http://localhost:8080 || echo "  ❌ Not accessible"
    
    echo "🌐 Web Server 1 (http://localhost:8081):"
    curl -s -o /dev/null -w "  Status: %{http_code}\n" http://localhost:8081 || echo "  ❌ Not accessible"
    
    echo "🌐 Web Server 2 (http://localhost:8082):"
    curl -s -o /dev/null -w "  Status: %{http_code}\n" http://localhost:8082 || echo "  ❌ Not accessible"
    
    echo "🗄️ Database (port 3306):"
    if nc -z localhost 3306 2>/dev/null; then
        echo "  ✅ Port 3306 accessible"
    else
        echo "  ❌ Port 3306 not accessible"
    fi
    
    echo "📊 Monitoring (http://localhost:3000):"
    curl -s -o /dev/null -w "  Status: %{http_code}\n" http://localhost:3000 || echo "  ❌ Not accessible"
}

# Show service endpoints
show_endpoints() {
    echo_info "Service Access Points:"
    echo "🔧 Load Balancer:     http://localhost:8080"
    echo "🌐 Web Server 1:      http://localhost:8081"
    echo "🌐 Web Server 2:      http://localhost:8082"
    echo "🗄️ Database:          localhost:3306"
    echo "📊 Grafana:           http://localhost:3000"
    echo "📊 Prometheus:        http://localhost:9090"
    echo ""
    echo "VM IP Addresses:"
    echo "  lb.local       192.168.56.10"
    echo "  web1.local     192.168.56.11"
    echo "  web2.local     192.168.56.12"
    echo "  db.local       192.168.56.13"
    echo "  monitor.local  192.168.56.14"
}

# SSH to VM (alternative method)
ssh_to_vm() {
    local vm=$1
    
    if [[ -z "$vm" ]]; then
        echo_error "Usage: $0 ssh <vm>"
        echo "Available VMs: lb, web1, web2, db, monitor"
        return 1
    fi
    
    case "$vm" in
        "lb")
            echo_info "Connecting to Load Balancer..."
            ssh -i ansible_key vagrant@192.168.56.10
            ;;
        "web1")
            echo_info "Connecting to Web Server 1..."
            ssh -i ansible_key vagrant@192.168.56.11
            ;;
        "web2")
            echo_info "Connecting to Web Server 2..."
            ssh -i ansible_key vagrant@192.168.56.12
            ;;
        "db")
            echo_info "Connecting to Database Server..."
            ssh -i ansible_key vagrant@192.168.56.13
            ;;
        "monitor")
            echo_info "Connecting to Monitoring Server..."
            ssh -i ansible_key vagrant@192.168.56.14
            ;;
        *)
            echo_error "Unknown VM: $vm"
            echo "Available VMs: lb, web1, web2, db, monitor"
            return 1
            ;;
    esac
}

# Check database status
check_database() {
    echo_info "Checking database status..."
    if ! command -v ansible &> /dev/null; then
        echo_error "Ansible not found. Cannot check database status."
        return 1
    fi
    
    ansible db.local -m shell -a "systemctl is-active mysql" 2>/dev/null | grep -v WARNING | tail -1
    ansible db.local -m shell -a "mysql -u root -e 'SELECT version();'" 2>/dev/null | grep -v WARNING | tail -2
}

# View service logs
view_logs() {
    local vm=$1
    local service=$2
    
    if [[ -z "$vm" || -z "$service" ]]; then
        echo_error "Usage: $0 logs <vm> <service>"
        echo "Examples:"
        echo "  $0 logs web1 apache2"
        echo "  $0 logs lb nginx"
        echo "  $0 logs db mysql"
        return 1
    fi
    
    echo_info "Showing logs for $service on $vm..."
    vagrant ssh "$vm" -c "sudo journalctl -u $service -n 20 --no-pager"
}

# Main command dispatcher
case "${1:-help}" in
    "test")
        test_endpoints
        ;;
    "endpoints")
        show_endpoints
        ;;
    "db-status")
        check_database
        ;;
    "ssh")
        ssh_to_vm "$2"
        ;;
    "logs")
        view_logs "$2" "$3"
        ;;
    "help"|*)
        show_help
        ;;
esac
