# Vagrant SSH Connection Issues - Solutions

## What was happening to your web2 VM:

### The Problem:
1. **Connection reset**: Your VM was dropping SSH connections
2. **Vagrant insecure key detected**: Vagrant was trying to replace the default insecure key with a new one, but this was failing
3. **Long startup times**: DNS resolution issues and unnecessary services were slowing down boot

### The Solutions Applied:

## 1. Fixed SSH Configuration
**Old configuration:**
```ruby
config.ssh.insert_key = true  # Caused conflicts
```

**New optimized configuration:**
```ruby
config.ssh.insert_key = false  # Use default Vagrant insecure key
# Default Vagrant key is automatically used, no need to specify path
config.ssh.keep_alive = true
config.ssh.connect_timeout = 30
```

## 2. Optimized VirtualBox Settings
**Changes made:**
- Disabled DNS resolution that was causing delays
- Disabled audio and serial ports for faster boot
- Added `auto_correct: true` to port forwarding to avoid conflicts

## 3. Improved Provisioning
**Old:** Shell script ran every time VM booted
**New:** Shell script runs only once with `run: "once"`

## 4. Network Optimizations
- Disabled problematic DNS resolvers
- Added SSH keep-alive settings
- Fixed hosts file configuration

## How to Use the Fixed Setup:

### Quick Commands:
```bash
# Use the optimized script
./manage.sh start         # Start all VMs
./manage.sh status        # Check status
./manage.sh restart web2  # Restart just web2
./manage.sh rebuild web2  # Completely rebuild web2 if issues persist
./manage.sh fix-ssh       # Fix SSH issues
```

### If You Still Have Issues:

1. **For persistent connection issues:**
   ```bash
   ./manage.sh rebuild web2
   ```

2. **For SSH problems:**
   ```bash
   ./manage.sh fix-ssh
   ```

3. **Clean start:**
   ```bash
   vagrant destroy -f
   ./manage.sh start
   ```

## Performance Improvements:

- ✅ **Faster boot times**: Disabled unnecessary services
- ✅ **Stable SSH**: Fixed key management conflicts  
- ✅ **Better networking**: Optimized DNS and connection settings
- ✅ **No more retries**: Proper SSH configuration prevents connection resets
- ✅ **One-time setup**: Provisioning scripts only run when needed

## What Each VM Does:
- **lb** (192.168.56.10): Load balancer (Nginx)
- **web1** (192.168.56.11): Web server 1 (Apache/PHP)
- **web2** (192.168.56.12): Web server 2 (Apache/PHP) 
- **db** (192.168.56.13): Database server (MySQL)
- **monitor** (192.168.56.14): Monitoring (Prometheus/Grafana)

The issues you were experiencing should now be resolved!
