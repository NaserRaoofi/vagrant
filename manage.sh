#!/bin/bash

# Vagrant Infrastructure Management Script
# Clean and optimized for better performance and reduced connection issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
echo_success() { echo -e "${GREEN}✅ $1${NC}"; }
echo_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
echo_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to check prerequisites
check_prerequisites() {
    echo_info "Checking prerequisites..."
    
    # Check if Vagrant is installed
    if ! command -v vagrant &> /dev/null; then
        echo_error "Vagrant is not installed!"
        exit 1
    fi
    
    # Check if VirtualBox is installed
    if ! command -v VBoxManage &> /dev/null; then
        echo_error "VirtualBox is not installed!"
        exit 1
    fi
    
    # Check if SSH keys exist
    if [[ ! -f "ansible_key" || ! -f "ansible_key.pub" ]]; then
        echo_warning "SSH keys not found. Generating new ones..."
        ssh-keygen -t ed25519 -f ansible_key -C "ansible@vagrant-infrastructure" -N ""
        chmod 600 ansible_key
        chmod 644 ansible_key.pub
        echo_success "SSH keys generated successfully"
    fi
    
    echo_success "Prerequisites check completed"
}

# Function to show status
show_status() {
    echo_info "Current VM Status:"
    vagrant status
}

# Function to clean up stuck processes and locks
cleanup_processes() {
    echo_info "Cleaning up any stuck processes..."
    
    # Kill any stuck vagrant or ruby processes
    pkill -f "vagrant up" 2>/dev/null || true
    pkill -f "ansible-playbook" 2>/dev/null || true
    
    # Wait for processes to cleanup
    sleep 3
    
    # Remove any potential lock files
    find .vagrant -name "*.lock" -delete 2>/dev/null || true
    
    echo_success "Cleanup completed"
}

# Function to start VMs one by one (safer approach)
start_sequential() {
    echo_info "Starting VMs sequentially to avoid conflicts..."
    
    local vms=("db" "web1" "web2" "lb" "monitor")
    
    for vm in "${vms[@]}"; do
        echo_info "Starting VM: $vm"
        if timeout 300 vagrant up "$vm"; then
            echo_success "VM $vm started successfully"
        else
            echo_error "Failed to start VM: $vm (timeout/error)"
            echo_info "You can try: vagrant destroy -f $vm && vagrant up $vm"
            return 1
        fi
        sleep 5  # Pause between VMs
    done
    
    echo_success "All VMs started successfully!"
}

# Function to start all VMs
start_all() {
    echo_info "Starting all VMs with optimized settings..."
    
    # Clean up any previous issues first
    cleanup_processes
    
    # Try starting all at once first, fall back to sequential if needed
    echo_info "Attempting to start all VMs..."
    if ! timeout 600 vagrant up; then
        echo_warning "Parallel start failed, trying sequential start..."
        start_sequential
    else
        echo_success "All VMs started successfully!"
    fi
    
    show_status
}

# Function to stop all VMs
stop_all() {
    echo_info "Stopping all VMs..."
    vagrant halt
    echo_success "All VMs stopped"
}

# Function to restart specific VM
restart_vm() {
    if [[ -z "$1" ]]; then
        echo_error "Please specify VM name: web1, web2, lb, db, or monitor"
        exit 1
    fi
    
    echo_info "Restarting VM: $1"
    vagrant reload "$1"
    echo_success "VM $1 restarted"
}

# Function to clean up and destroy VMs
cleanup() {
    echo_warning "This will destroy all VMs and remove their data!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Destroying all VMs..."
        vagrant destroy -f
        echo_success "All VMs destroyed"
    else
        echo_info "Cleanup cancelled"
    fi
}

# Function to install packages manually on all VMs
install_packages_manually() {
    echo_info "Installing essential packages manually on all VMs..."
    
    echo_info "Installing nginx on load balancer..."
    vagrant ssh lb -c "
        sudo bash -c '
            export DEBIAN_FRONTEND=noninteractive
            pkill -f apt-get || true
            rm -f /var/lib/dpkg/lock* || true
            apt-get update -qq || true
            apt-get install -y nginx || echo \"nginx install failed\"
            systemctl enable nginx || true
        '
    " && echo_success "Nginx installed on lb" || echo_warning "Issues installing on lb"
    
    echo_info "Installing web packages on web servers..."
    for vm in web1 web2; do
        vagrant ssh "$vm" -c "
            sudo bash -c '
                export DEBIAN_FRONTEND=noninteractive
                pkill -f apt-get || true
                rm -f /var/lib/dpkg/lock* || true
                apt-get update -qq || true
                apt-get install -y nginx php-fpm php-mysql || echo \"web packages install failed\"
                systemctl enable nginx php8.1-fpm || true
            '
        " || echo_warning "Failed to connect to $vm"
    done
    
    echo_info "Installing MySQL on database server..."
    vagrant ssh db -c "
        sudo bash -c '
            export DEBIAN_FRONTEND=noninteractive
            pkill -f apt-get || true
            rm -f /var/lib/dpkg/lock* || true
            apt-get update -qq || true
            apt-get install -y mysql-server || echo \"mysql install failed\"
            systemctl enable mysql || true
        '
    " || echo_warning "Failed to connect to db"
    
    echo_info "Installing monitoring packages..."
    vagrant ssh monitor -c "
        sudo bash -c '
            export DEBIAN_FRONTEND=noninteractive
            pkill -f apt-get || true
            rm -f /var/lib/dpkg/lock* || true
            apt-get update -qq || true
            apt-get install -y wget curl htop || echo \"monitoring packages install failed\"
        '
    " || echo_warning "Failed to connect to monitor"
    
    echo_success "Package installation completed"
}

# Function to run Ansible provisioning with timeout
provision_with_timeout() {
    echo_info "Running Ansible provisioning with timeout protection..."
    
    # Set timeout for the entire provisioning process (20 minutes)
    if timeout 1200 vagrant provision monitor; then
        echo_success "Ansible provisioning completed successfully"
    else
        echo_error "Ansible provisioning timed out or failed"
        echo_info "You can try: ./manage.sh provision-retry"
        return 1
    fi
}

# Function to retry provisioning if it fails
provision_retry() {
    echo_info "Retrying Ansible provisioning..."
    
    # Clean up any stuck SSH connections
    cleanup_processes
    
    # Try provisioning again
    provision_with_timeout
}

# Function to SSH into a VM
ssh_vm() {
    if [[ -z "$1" ]]; then
        echo_error "Please specify VM name: web1, web2, lb, db, or monitor"
        exit 1
    fi
    
    echo_info "Connecting to VM: $1"
    vagrant ssh "$1"
}

# Function to fix SSH issues
fix_ssh() {
    echo_info "Fixing SSH connection issues..."
    
    # Remove old SSH entries
    echo_info "Cleaning old SSH entries..."
    ssh-keygen -R 192.168.56.10 2>/dev/null || true
    ssh-keygen -R 192.168.56.11 2>/dev/null || true
    ssh-keygen -R 192.168.56.12 2>/dev/null || true
    ssh-keygen -R 192.168.56.13 2>/dev/null || true
    ssh-keygen -R 192.168.56.14 2>/dev/null || true
    
    # Reset SSH configuration
    echo_info "Resetting SSH configuration..."
    for vm in lb web1 web2 db monitor; do
        vagrant ssh "$vm" -c "sudo systemctl restart ssh" 2>/dev/null || true
    done
    
    echo_success "SSH issues fixed"
}

# Function to rebuild problematic VM
rebuild_vm() {
    if [[ -z "$1" ]]; then
        echo_error "Please specify VM name: web1, web2, lb, db, or monitor"
        exit 1
    fi
    
    echo_warning "This will destroy and recreate VM: $1"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Rebuilding VM: $1"
        vagrant destroy -f "$1"
        vagrant up "$1"
        echo_success "VM $1 rebuilt successfully"
    else
        echo_info "Rebuild cancelled"
    fi
}

# Function to show help
show_help() {
    echo "Vagrant Infrastructure Management Script (Optimized)"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       - Start all VMs in correct order"
    echo "  start-seq   - Start VMs one by one (safer for connection issues)"
    echo "  cleanup-locks - Clean up stuck Vagrant processes and locks"
    echo "  stop        - Stop all VMs"
    echo "  status      - Show current VM status"
    echo "  restart VM  - Restart specific VM (web1, web2, lb, db, monitor)"
    echo "  rebuild VM  - Destroy and recreate specific VM"
    echo "  ssh VM      - SSH into specific VM"
    echo "  provision   - Run Ansible provisioning (with timeout protection)"
    echo "  provision-retry - Retry Ansible provisioning if it failed"
    echo "  install-packages - Install packages manually (bypass apt issues)"
    echo "  fix-ssh     - Fix SSH connection issues"
    echo "  cleanup     - Destroy all VMs"
    echo "  help        - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 restart web2"
    echo "  $0 rebuild web2   # For persistent issues"
    echo "  $0 ssh lb"
    echo "  $0 fix-ssh"
    echo ""
    echo "Troubleshooting:"
    echo "  - If a VM has connection issues: $0 rebuild [vm_name]"
    echo "  - If SSH is broken: $0 fix-ssh"
    echo "  - If startup is slow: VMs are optimized to start faster"
}

# Main script logic
case "${1:-help}" in
    "start")
        check_prerequisites
        start_all
        ;;
    "start-seq")
        check_prerequisites
        cleanup_processes
        start_sequential
        ;;
    "cleanup-locks")
        cleanup_processes
        ;;
    "stop")
        stop_all
        ;;
    "status")
        show_status
        ;;
    "restart")
        restart_vm "$2"
        ;;
    "rebuild")
        rebuild_vm "$2"
        ;;
    "ssh")
        ssh_vm "$2"
        ;;
    "provision")
        provision_with_timeout
        ;;
    "provision-retry")
        provision_retry
        ;;
    "install-packages")
        install_packages_manually
        ;;
    "fix-ssh")
        fix_ssh
        ;;
    "cleanup")
        cleanup
        ;;
    "help"|*)
        show_help
        ;;
esac
