/*
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
  frappe/erpnext:v16.26.1 \
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


After your NixOS server finishes the `nixos-rebuild switch`, the system will automatically pull the new `v16.26.1` images and recreate the containers based on your new module.

However, because you updated the ERPNext version, you **must** run database migrations manually to apply any schema changes that come with the new version.

Here are the exact commands you need to execute in your terminal:

### 1. Verify the New Containers are Running

First, ensure NixOS successfully spun up the new split-queue architecture and isn't stuck in a restart loop.

```bash
sudo docker ps -a

```

*Look for `erpnext-queue-long` and `erpnext-queue-short` in the names list, and ensure their status says "Up".*

### 2. Run the Database Migration

This is the most critical step of a version upgrade. It applies new database schemas and patches to your persistent MariaDB data.

```bash
sudo docker exec -it erpnext-backend bench --site erp.protoplast.in migrate

```

*(Note: If you have multiple sites or named your site folder differently inside the volume, replace `erp.protoplast.in` with the exact directory name inside `/var/lib/erpnext/sites`).*

### 3. Clear the Cache

Flush the Redis cache to ensure no old, compiled assets or outdated configuration states are served to the frontend.

```bash
sudo docker exec -it erpnext-backend bench --site erp.protoplast.in clear-cache

```

### 4. Restart the ERPNext Stack (Recommended)

Because the background workers were running while you migrated the database, it is best practice to restart all the Frappe-related containers so they boot up cleanly against the freshly migrated database.

Since NixOS is managing these via Systemd, use `systemctl` rather than standard Docker commands:

```bash
sudo systemctl restart docker-erpnext-*

```

Once that restart completes, your ERPNext instance will be fully upgraded to v16.26.1 and ready to use!

sudo docker exec -it erpnext-backend bench --site erp.protoplast.in set-admin-password <your-new-password>
=============================================================================
*/
{
  flake.nixosModules.protoplast_erpnext = { config, pkgs, lib, inputs, ... }:
  
  let
    frappeImage = "frappe/erpnext:v16.26.1";
  in
  {

    # 2. Apply standard directory rules
    systemd.tmpfiles.rules = [
      "d /var/lib/erpnext/sites 0755 1000 1000 -"
      "d /var/lib/erpnext/logs 0755 1000 1000 -"
      "d /var/lib/erpnext/mysql 0755 999 999 -" 
      "d /var/lib/erpnext/redis-queue 0755 999 999 -" # Changed to 999
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
  
      erpnext-queue-long = {
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

      erpnext-queue-short = {
        image = frappeImage;
        dependsOn = [ "erpnext-backend" ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
        cmd = [ "bench" "worker" "--queue" "short,default" ]; 
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
      "docker-erpnext-queue-long"
      "docker-erpnext-queue-short"
      "docker-erpnext-scheduler"
      "docker-erpnext-websocket"
      "docker-erpnext-frontend"
    ] (name: {
      serviceConfig = { Restart = lib.mkForce "always"; RestartSec = lib.mkForce "10s"; };
    });
  };
}