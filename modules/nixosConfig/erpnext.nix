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

ENV_FILE="/run/secrets/erpnext.env"

# Source the env file to make variables available to this bash script
set -a
source $ENV_FILE
set +a

echo "Spinning up ephemeral configuration container for $SITE_NAME..."
sudo docker run --rm \
  --network=frappe_network \
  --env-file "$ENV_FILE" \
  -v /var/lib/erpnext/sites:/home/frappe/frappe-bench/sites \
  -v /var/lib/erpnext/logs:/home/frappe/frappe-bench/logs \
  frappe/erpnext:v16.25.0 \
  bash -c '
      echo "Waiting for MariaDB and Redis..."
      wait-for-it -t 120 $DB_HOST:$DB_PORT
      wait-for-it -t 120 $REDIS_CACHE
      wait-for-it -t 120 $REDIS_QUEUE
      
      echo "Generating app list..."
    
    echo "Generating app list..."
    ls -1 apps > sites/apps.txt

    echo "Creating common_site_config.json skeleton..."
    if [ ! -f sites/common_site_config.json ]; then
        echo "{}" > sites/common_site_config.json
    fi

    echo "Configuring common_site_config.json..."
    bench set-config -g db_host $DB_HOST
    bench set-config -gp db_port $DB_PORT
    bench set-config -g redis_cache "redis://$REDIS_CACHE"
    bench set-config -g redis_queue "redis://$REDIS_QUEUE"
    bench set-config -g redis_socketio "redis://$REDIS_QUEUE"
    bench set-config -gp socketio_port 9000

    if [ ! -d "sites/$SITE_NAME" ]; then
        echo "Creating new site ($SITE_NAME)..."
        bench new-site $SITE_NAME \
          --mariadb-user-host-login-scope="%" \
          --admin-password="$ADMIN_PASSWORD" \
          --db-root-username=root \
          --db-root-password="$DB_PASSWORD" \
          --install-app erpnext \
          --set-default
          
        echo "Fixing host_name for email links..."
        bench --site $SITE_NAME set-config host_name "https://$SITE_NAME"
    else
        echo "Site $SITE_NAME already exists, skipping creation."
    fi
    
    echo "Initialization complete!"
  '

echo "Restarting background ERPNext services to apply the new config..."
sudo systemctl restart docker-erpnext-*

echo "Done! ERPNext is configured exclusively via the SOPS template."
=============================================================================
*/
{
  flake.nixosModules.protoplast_tb_postgres = { config, pkgs, lib, inputs, ... }:
  
  let
    frappeImage = "frappe/erpnext:v16.25.0";
  in
  {
    # 1. Pull the entire .env file as a single secret
    sops.secrets."erpnext.env" = {
      sopsFile = "${inputs.self}/secrets/${config.networking.hostName}_erpnext.env";
      format = "dotenv";
    };
  
    # 2. Apply standard directory rules
    systemd.tmpfiles.rules = [
      "d /var/lib/erpnext/sites 0755 1000 1000 -"
      "d /var/lib/erpnext/logs 0755 1000 1000 -"
      "d /var/lib/erpnext/mysql 0755 999 999 -" 
      "d /var/lib/erpnext/redis-queue 0755 1000 1000 -"
    ];
    
    # 3. The Containers
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
      
      erpnext-db = {
        image = "mariadb:11.8";
        volumes = [ "/var/lib/erpnext/mysql:/var/lib/mysql" ];
        # Pass the decrypted file directly to Docker
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
        cmd = [
          "--character-set-server=utf8mb4"
          "--collation-server=utf8mb4_unicode_ci"
          "--skip-character-set-client-handshake"
          "--innodb-buffer-pool-size=512M" 
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
  
      erpnext-backend = {
        image = frappeImage;
        dependsOn = [ "erpnext-db" "erpnext-redis-cache" "erpnext-redis-queue" ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        extraOptions = [ "--network=frappe_network" ];
      };
  
      erpnext-worker = {
        image = frappeImage;
        dependsOn = [ "erpnext-backend" ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
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
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
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
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
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
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
        cmd = [ "nginx-entrypoint.sh" ];
        ports = [ "127.0.0.1:8080:8080" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        extraOptions = [ "--network=frappe_network" ];
      };
    };
  
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
      serviceConfig = { Restart = lib.mkForce "always"; RestartSec = lib.mkForce "10s"; };
    });
  };
}