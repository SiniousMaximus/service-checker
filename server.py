#!/usr/bin/env python3
import http.server
import socketserver
import sys
import json
import os
import argparse
import signal
import time
import subprocess
import yaml
from cerberus import Validator
from pathlib import Path


cwd = Path.cwd()
default_config_path = f"{cwd}/config/config.yml"

class CustomHandler(http.server.BaseHTTPRequestHandler):
    
    def do_GET(self): # GET http requests
        # Server health check
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<b1>Service Checker is running!</b1>')
        
        # Services check
        elif self.path.startswith('/api/service/'):
            service_name = self.path.split('/')[-1]
            response = run_service_command(service_name)
            
            status_code = 200 if response['success'] else 500
            
            self.send_response(status_code)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())
        
        # No check
        else:
            self.send_response(404)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>404 - Page Not Found</h1>')

def get_pid_file(port):
    # Get the PID file path for a given port
    return f'/tmp/webserver_{port}.pid'

def get_log_file(port):
    # Get the log file path for a given port
    return f'/tmp/webserver_{port}.log'

def is_running(port):
    # Check if server is running on given port
    pid_file = get_pid_file(port)
    if not os.path.exists(pid_file):
        return False
    
    try:
        with open(pid_file, 'r') as f:
            pid = int(f.read().strip())
        
        # Check if process exists
        os.kill(pid, 0)
        return True
    except (OSError, ValueError):
        # Process doesn't exist, remove stale PID file
        if os.path.exists(pid_file):
            os.remove(pid_file)
        return False

def get_pid(port):
    # Get PID of running server
    pid_file = get_pid_file(port)
    if not os.path.exists(pid_file):
        return None
    
    try:
        with open(pid_file, 'r') as f:
            return int(f.read().strip())
    except (OSError, ValueError):
        return None

def daemonize(port):
    # Fork the process to run in background
    try:
        pid = os.fork()
        if pid > 0:
            # Wait a moment to ensure child process starts
            time.sleep(0.5)
            sys.exit(0)
    except OSError as e:
        print(f"Fork failed: {e}")
        sys.exit(1)
    
    # Decouple from parent environment
    os.chdir('/')
    os.setsid()
    os.umask(0)
    
    # Second fork
    try:
        pid = os.fork()
        if pid > 0:
            sys.exit(0)
    except OSError as e:
        print(f"Fork failed: {e}")
        sys.exit(1)
    
    # Redirect stdout and stderr to log 
    sys.stdout.flush()
    sys.stderr.flush()
    
    log_file = get_log_file(port)
    
    with open('/dev/null', 'r') as f:
        os.dup2(f.fileno(), sys.stdin.fileno())
    with open(log_file, 'a+') as f:
        os.dup2(f.fileno(), sys.stdout.fileno())
    with open(log_file, 'a+') as f:
        os.dup2(f.fileno(), sys.stderr.fileno())

def start_server(port=8000, daemon=False):
    # Start the web server
    if is_running(port):
        print(f"Server is already running on port {port} (PID: {get_pid(port)})")
        sys.exit(1)

    print(f"Starting server on port {port}...")
    
    if daemon:
        daemonize(port)
        # Write PID file after daemonizing
        with open(get_pid_file(port), 'w') as f:
            f.write(str(os.getpid()))
    
    # Log server start
    log_file = get_log_file(port) if daemon else None
    if log_file:
        with open(log_file, 'a') as f:
            f.write(f"Server started at {time.strftime('%Y-%m-%d %H:%M:%S')}")
            f.write(f"PID: {os.getpid()}, Port: {port}")
            f.write(f"Using config file: {config_file_path}\n")
    else:
        print(f"Server started at {time.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"PID: {os.getpid()}, Port: {port}")
        print(f"Using config file: {config_file_path}\n")
    
    Handler = CustomHandler
    socketserver.TCPServer.allow_reuse_address = True # This seemes to fix a bug where after retsarting, the port was still unavailable for some time
     
    try:
        with socketserver.TCPServer(("0.0.0.0", port), Handler) as httpd:
            print(f"Server listening on http://0.0.0.0:{port}/")
            sys.stdout.flush() 
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
    except OSError as e:
        if e.errno == 98:  # Address already in use
            print(f"Error: Port {port} is already in use")
        else:
            print(f"OS Error: {e}")
    except Exception as e:
        print(f"Error: {e}")

def stop_server(port):
    # Stop the web server
    if not is_running(port):
        print(f"No server is running on port {port}")
        return
    
    pid = get_pid(port)
    print(f"Stopping server listening on http://0.0.0.0:{port}/ (PID: {pid})...")
    
    try:
        os.kill(pid, signal.SIGTERM)
        
        # Wait for process to terminate
        for i in range(10):
            time.sleep(0.5)
            if not is_running(port):
                print("Server stopped successfully")
                return
        
        # Force kill if still running
        print("Server didn't stop gracefully, forcing...")
        os.kill(pid, signal.SIGKILL)
        time.sleep(0.5)
        
        # Removing any lefover PID file and log
        files = [get_pid_file(port), get_log_file(port)]
        for file in files:
            if os.path.exists(file):
                os.remove(file)
        
        print("Server stopped (forced)")

    except OSError as e:
        print(f"Error stopping server: {e}")

def status_server(port):
    # Check server status
    if is_running(port):
        pid = get_pid(port)
        print(f"Server is running on port {port}")
        print(f"PID: {pid}")
        print(f"URL: http://0.0.0.0:{port}/")
        print(f"Log file: {get_log_file(port)}")
    else:
        print(f"Server is not running on port {port}")

def restart_server(port, daemon):
    # Restart the web server
    if is_running(port):
        print(f"Restarting server listening on http://0.0.0.0:{port}/ ...")
        stop_server(port)
        time.sleep(1)
    else:
        print(f"Server is not running on port {port}")
        sys.exit(0)
    start_server(port, daemon)
    print(f"Server restarted on port {port}")

def load_and_check_config(config_file_path):

    # Load configuration from config.yml 
    config_file = config_file_path or default_config_path
    
    if not os.path.exists(config_file):
        print(f"Warning: config.yml not found at {config_file}")
        return {}

    # Defining the schema for EACH service
    service_schema = {
        'hostname': {'type': 'string', 'required': False, 'default': 'hostname not specified'},
        'service_type': {'type': 'string', 'required': True},
        'user': {'type': 'string', 'required': True},
        'port': {'type': 'integer', 'required': False, 'default': 22},
        'ssh_key': {'type': 'string', 'required': True},
        'ip': {'type': 'string', 'required': False},
    }

    try:
        with open(config_file, 'r') as f:
            data = yaml.safe_load(f)
        
        # Validate EACH service individually
        validated_config = {}
        v = Validator(service_schema)
        
        for service_name, service_config in data.items():
            if v.validate(service_config):
                validated_config[service_name] = v.normalized(service_config)
            else:
                print(f"Validation errors for '{service_name}': {v.errors}")
                return {}
        
        return validated_config
        
    except yaml.YAMLError as e:
        print(f"Error parsing config.yml: {e}")
        return {}
    except Exception as e:
        print(f"Error reading config.yml: {e}")
        return {}

def run_service_command(service_name):
    # Load config file
    config = load_and_check_config(config_file_path)
    service_info = config.get(service_name)

    if not service_info:
        return {
            'success': False,
            'error': f"Service '{service_name}' was not found in the config file"
        }

    # Get the data from config.yml
    hostname = service_info.get('hostname')
    service_type = service_info.get('service_type')
    user = service_info.get("user")
    ip = service_info.get("ip")
    port = service_info.get("port")
    ssh_key = service_info.get("ssh_key")
    
    # Main service check logic
    match service_type:
        case "systemd":
            remote_cmd = f'systemctl is-active {service_name}'
        case "openrc":
            remote_cmd = f"rc-service {service_name} status"
        case "docker-health":
            remote_cmd = f"docker inspect --format={{{{.State.Health.Status}}}} {service_name}"
        case "docker-status":
            remote_cmd = f"docker inspect --format={{{{.State.Status}}}} {service_name}"
        case _:
            return {
                'success': False,
                'error': f'Unknown service type: {service_type}'
            }
        

    # Sending the ssh command
    ssh_cmd = f'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {user}@{ip} -p {port} -i {ssh_key} "{remote_cmd}"'
    
    try:
        result = subprocess.run(
            ssh_cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30
        )

        status = result.stdout.strip()
        
        if service_type == 'openrc':
            # Extract status from "* status: started" output of "rc-service service_name status" command
            if ':' in status:
                status = status.split(':')[-1].strip()

        # Change status to a simple "up" or "down" message
        if status == "started" or status == "active" or status == "running" or status == "healthy":
            status = "up"
        else:
            status = "down"
        
        return {
            'service_name': service_name,
            'success': result.returncode == 0,
            'hostname': hostname,
            'service_type': service_type,
            'status': status
        }

    except subprocess.TimeoutExpired:
        return {
            'success': False,
            'error': 'Command timed out'
        }
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Simple HTTP Server to check remote services via ssh')
    parser.add_argument('command', choices=['start', 'stop', 'restart', 'status'],
                        help='Command to execute')
    parser.add_argument('-p', '--port', type=int, default=8000,
                        help='Port number (default: 8000)')
    parser.add_argument('-d', '--daemon', action='store_true',
                        help='Run in background')
    parser.add_argument('-c', '--config', action='store', dest='config_file_path', default=default_config_path,
                        help='Config file path (default=$PWD/config/config.yml)')
    
    args = parser.parse_args()
    
    config_file_path = args.config_file_path 
    match args.command:
        case 'start':
            start_server(args.port, args.daemon)
        case 'stop':
            stop_server(args.port)
        case 'restart':
            restart_server(args.port, args.daemon)
        case 'status':
            status_server(args.port)

    