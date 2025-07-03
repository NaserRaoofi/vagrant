# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Pre-flight check: Ensure Ansible is installed on host
  unless system("which ansible > /dev/null 2>&1")
    puts "\n❌ ERROR: Ansible is not installed on your local machine!"
    puts "🔧 Please install Ansible first:"
    puts "   Ubuntu/Debian: sudo apt update && sudo apt install ansible"
    puts "   CentOS/RHEL:   sudo yum install ansible"
    puts "   macOS:         brew install ansible"
    puts "   pip:           pip install ansible"
    puts "\n💡 This infrastructure uses HOST-BASED Ansible (industry standard)"
    puts "   Your machine controls all VMs via SSH - no Ansible needed on VMs\n"
    exit 1
  end
  
  puts "✅ Ansible found: Using host-based control"
  
  # Define the base box for all VMs
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_check_update = false

  # SSH configuration - using default Vagrant insecure keys
  config.ssh.forward_agent = true
  config.ssh.insert_key = false   # Use default Vagrant insecure key
  config.ssh.keep_alive = true
  config.ssh.connect_timeout = 60
  config.ssh.shell = "bash -l"

  # Configure shared VM settings
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
    vb.cpus = 2
    # Optimize VirtualBox settings for faster boot
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "off"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "off"]
    vb.customize ["modifyvm", :id, "--audio", "none"]
    vb.customize ["modifyvm", :id, "--uart1", "off"]
    vb.customize ["modifyvm", :id, "--uart2", "off"]
  end

  # One-time setup - simplified for default Vagrant keys
  config.vm.provision "shell", run: "once", inline: <<-SHELL
    echo "Setting up SSH access using default Vagrant insecure keys..."
    
    # Ensure SSH service is running and configured properly
    systemctl enable ssh
    systemctl restart ssh
    
    echo "✅ SSH configuration complete - using default Vagrant keys"
  SHELL

  # Load Balancer VM
  config.vm.define "lb" do |lb|
    lb.vm.hostname = "lb.local"
    lb.vm.network "private_network", ip: "192.168.56.10"
    lb.vm.provider "virtualbox" do |vb|
      vb.name = "LoadBalancer"
      vb.memory = "512"
      vb.cpus = 1
    end
    # Port forwarding for load balancer
    lb.vm.network "forwarded_port", guest: 80, host: 8080, auto_correct: true
    lb.vm.network "forwarded_port", guest: 443, host: 8443, auto_correct: true
  end

  # Web Server 1
  config.vm.define "web1" do |web1|
    web1.vm.hostname = "web1.local"
    web1.vm.network "private_network", ip: "192.168.56.11"
    web1.vm.provider "virtualbox" do |vb|
      vb.name = "WebServer1"
      vb.memory = "1024"
      vb.cpus = 2
    end
    # Port forwarding for direct access
    web1.vm.network "forwarded_port", guest: 80, host: 8081, auto_correct: true
  end

  # Web Server 2
  config.vm.define "web2" do |web2|
    web2.vm.hostname = "web2.local"
    web2.vm.network "private_network", ip: "192.168.56.12"
    web2.vm.provider "virtualbox" do |vb|
      vb.name = "WebServer2"
      vb.memory = "1024"
      vb.cpus = 2
    end
    # Port forwarding for direct access
    web2.vm.network "forwarded_port", guest: 80, host: 8082, auto_correct: true
  end

  # Database Server
  config.vm.define "db" do |db|
    db.vm.hostname = "db.local"
    db.vm.network "private_network", ip: "192.168.56.13"
    db.vm.provider "virtualbox" do |vb|
      vb.name = "DatabaseServer"
      vb.memory = "2048"
      vb.cpus = 2
    end
    # Port forwarding for database access
    db.vm.network "forwarded_port", guest: 3306, host: 3306, auto_correct: true
    db.vm.network "forwarded_port", guest: 5432, host: 5432, auto_correct: true
  end

  # Monitoring Server
  config.vm.define "monitor" do |monitor|
    monitor.vm.hostname = "monitor.local"
    monitor.vm.network "private_network", ip: "192.168.56.14"
    monitor.vm.provider "virtualbox" do |vb|
      vb.name = "MonitoringServer"
      vb.memory = "2048"
      vb.cpus = 2
    end
    # Port forwarding for monitoring services
    monitor.vm.network "forwarded_port", guest: 3000, host: 3000, auto_correct: true  # Grafana
    monitor.vm.network "forwarded_port", guest: 9090, host: 9090, auto_correct: true  # Prometheus
    
    # Run Ansible from HOST machine using default Vagrant insecure key
    # This runs after ALL VMs are up and provisions each VM with its role
    monitor.vm.provision "ansible", run: "always" do |ansible|
      ansible.playbook = "ansible/site.yml"
      ansible.inventory_path = "ansible/inventory.ini"
      ansible.limit = "all"
      ansible.verbose = true
      ansible.host_key_checking = false
      ansible.raw_arguments = ["--timeout=300"]
      # Using default Vagrant insecure key
      ansible.extra_vars = {
        ansible_ssh_private_key_file: "~/.vagrant.d/insecure_private_key"
      }
    end
  end

  # Global provisioning - update hosts file on all VMs (run once)
  config.vm.provision "shell", run: "once", inline: <<-SHELL
    echo "Updating hosts file with VM network configuration..."
    # Update hosts file with all VM IPs
    cat >> /etc/hosts << 'EOF'
192.168.56.10   lb.local loadbalancer
192.168.56.11   web1.local webserver1
192.168.56.12   web2.local webserver2
192.168.56.13   db.local database
192.168.56.14   monitor.local monitoring
EOF
    echo "✅ Network configuration complete"
  SHELL
end
