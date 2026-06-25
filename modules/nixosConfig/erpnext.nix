/*

# secrets/server.yaml
erpnext_db_password: "your_secure_database_root_password_here"
erpnext_admin_password: "your_secure_web_admin_password_here"

=============================================================================
ERPNext Initialization Script
=============================================================================
Run this manually on the host after the system boots for the first time to 
bootstrap the MariaDB database and create the site_config.json file.

#!/usr/bin/env bash

echo "Fetching ERPNext Secrets from RAM..."
DB_PASS=$(sudo cat /run/secrets/erpnext_db_password)
ADMIN_PASS=$(sudo cat /run/secrets/erpnext_admin_password)

echo "Spinning up ephemeral configuration container..."
sudo docker run --rm \
  --network=frappe_network \
  -v /var/lib/erpnext/sites:/home/frappe/frappe-bench/sites \
  -v /var/lib/erpnext/logs:/home/frappe/frappe-bench/logs \
  -e DB_PASS="$DB_PASS" \
  -e ADMIN_PASS="$ADMIN_PASS" \
  frappe/erpnext:v16.25.0 \
  bash -c '
    echo "Waiting for MariaDB and Redis..."
    wait-for-it -t 120 erpnext-db:3306
    wait-for-it -t 120 erpnext-redis-cache:6379
    wait-for-it -t 120 erpnext-redis-queue:6379

    echo "Generating app list..."
    ls -1 apps > sites/apps.txt

    echo "Configuring common_site_config.json..."
    bench set-config -g db_host erpnext-db
    bench set-config -gp db_port 3306
    bench set-config -g redis_cache "redis://erpnext-redis-cache:6379"
    bench set-config -g redis_queue "redis://erpnext-redis-queue:6379"
    bench set-config -g redis_socketio "redis://erpnext-redis-queue:6379"
    bench set-config -gp socketio_port 9000

    if [ ! -d sites/frontend ]; then
        echo "Creating new site (frontend)..."
        bench new-site frontend \
          --mariadb-user-host-login-scope="%" \
          --admin-password="$ADMIN_PASS" \
          --db-root-username=root \
          --db-root-password="$DB_PASS" \
          --install-app erpnext \
          --set-default
    else
        echo "Site frontend already exists, skipping creation."
    fi
    
    echo "Initialization complete!"
  '

echo "Restarting background ERPNext services to apply the new config..."
sudo systemctl restart \
  docker-erpnext-backend \
  docker-erpnext-worker \
  docker-erpnext-scheduler \
  docker-erpnext-websocket \
  docker-erpnext-frontend

echo "Done! ERPNext should be spinning up normally now."
=============================================================================
*/

{
  flake.nixosModules.protoplast_erpnext = { config, pkgs, lib, ... }:
  let
    frappeImage = "frappe/erpnext:v16.25.0";
  in
  {
    systemd.tmpfiles.rules = [
      "d /var/lib/erpnext/sites 0755 1000 1000 -"
      "d /var/lib/erpnext/logs 0755 1000 1000 -"
      "d /var/lib/erpnext/mysql 0755 999 999 -" 
      "d /var/lib/erpnext/redis-queue 0755 1000 1000 -"
    ];
  
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
  
      # --- Persistence & Cache ---
      erpnext-db = {
        image = "mariadb:11.8";
        # Mount the decrypted SOPS secret directly into the container
        volumes = [ 
          "/var/lib/erpnext/mysql:/var/lib/mysql" 
          "/run/secrets/erpnext_db_password:/run/secrets/erpnext_db_password:ro"
        ];
        environment = {
          "MARIADB_ROOT_PASSWORD_FILE" = "/run/secrets/erpnext_db_password";
        };
        cmd = [
          "--character-set-server=utf8mb4"
          "--collation-server=utf8mb4_unicode_ci"
          "--skip-character-set-client-handshake"
          "--innodb-buffer-pool-size=128M" 
          "--max-connections=50"
        ];
        extraOptions = [ "--network=frappe_network" ];
      };
  
      erpnext-redis-cache = {
        image = "redis:6.2-alpine";
        cmd = [ "redis-server" "--maxmemory" "128mb" "--maxmemory-policy" "allkeys-lru" ];
        extraOptions = [ "--network=frappe_network" ];
      };
  
      erpnext-redis-queue = {
        image = "redis:6.2-alpine";
        volumes = [ "/var/lib/erpnext/redis-queue:/data" ];
        extraOptions = [ "--network=frappe_network" ];
      };
  
      # --- ERPNext App Components ---
      erpnext-backend = {
        image = frappeImage;
        dependsOn = [ "erpnext-db" "erpnext-redis-cache" "erpnext-redis-queue" ];
        environment = {
          "GUNICORN_WORKERS" = "1";
          "GUNICORN_THREADS" = "2";
          "GUNICORN_TIMEOUT" = "120";
        };
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        extraOptions = [ "--network=frappe_network" ];
      };
  
      erpnext-worker = {
        image = frappeImage;
        dependsOn = [ "erpnext-backend" ];
        environment = {
          "FRAPPE_REDIS_CACHE" = "redis://erpnext-redis-cache:6379";
          "FRAPPE_REDIS_QUEUE" = "redis://erpnext-redis-queue:6379";
        };
        cmd = [ "bench" "worker" "--queue" "long,default,short" ]; 
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        extraOptions = [ "--network=frappe_network" ];
      };
  
      erpnext-scheduler = {
        image = frappeImage;
        dependsOn = [ "erpnext-backend" ];
        cmd = [ "bench" "schedule" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        extraOptions = [ "--network=frappe_network" ];
      };
  
      erpnext-websocket = {
        image = frappeImage;
        dependsOn = [ "erpnext-backend" ];
        environment = {
          "FRAPPE_REDIS_CACHE" = "redis://erpnext-redis-cache:6379";
          "FRAPPE_REDIS_QUEUE" = "redis://erpnext-redis-queue:6379";
          "NODE_OPTIONS" = "--max-old-space-size=128";
        };
        cmd = [ "node" "/home/frappe/frappe-bench/apps/frappe/socketio.js" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        extraOptions = [ "--network=frappe_network" ];
      };
  
      erpnext-frontend = {
        image = frappeImage;
        dependsOn = [ "erpnext-backend" "erpnext-websocket" ];
        cmd = [ "nginx-entrypoint.sh" ];
        environment = {
          "BACKEND" = "erpnext-backend:8000";
          "SOCKETIO" = "erpnext-websocket:9000";
          "FRAPPE_SITE_NAME_HEADER" = "frontend";
          "UPSTREAM_REAL_IP_ADDRESS" = "127.0.0.1";
          "UPSTREAM_REAL_IP_HEADER" = "X-Forwarded-For";
          "UPSTREAM_REAL_IP_RECURSIVE" = "off";
          "PROXY_READ_TIMEOUT" = "120";
          "CLIENT_MAX_BODY_SIZE" = "50m";
        };
        ports = [ "127.0.0.1:8080:8080" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        extraOptions = [ "--network=frappe_network" ];
      };
    };
  
    # Merge the network creation service and the crash-loop suppressions into a single attribute set
    systemd.services = {
      "docker-network-frappe" = {
        description = "Create frappe_network docker bridge";
        wantedBy = [ "multi-user.target" ];
        after = [ "docker.service" ];
        requires = [ "docker.service" ];
        serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
        script = ''${pkgs.docker}/bin/docker network create frappe_network || true'';
      };
    } // lib.genAttrs [
      "docker-erpnext-backend"
      "docker-erpnext-worker"
      "docker-erpnext-scheduler"
      "docker-erpnext-websocket"
      "docker-erpnext-frontend"
    ] (name: {
      serviceConfig = {
        Restart = lib.mkForce "always";
        RestartSec = lib.mkForce "10s";
      };
    });
  };
}