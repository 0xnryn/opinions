{
  flake.nixosModules.protoplast_erpnext = { config, pkgs, lib, ... }:
  let
    frappeImage = "frappe/erpnext:v16.23.1";
    defaultPass = "admin";
  in
  {
    systemd.tmpfiles.rules = [
      "d /var/lib/erpnext/sites 0755 1000 1000 -"
      "d /var/lib/erpnext/logs 0755 1000 1000 -"
      "d /var/lib/erpnext/mysql 0755 999 999 -" 
      "d /var/lib/erpnext/redis-queue 0755 1000 1000 -"
      "d /var/lib/thingsboard/data 0775 799 799 -" 
      "d /var/lib/thingsboard/logs 0775 799 799 -" 
    ];
  
    systemd.services."docker-network-frappe" = {
      description = "Create frappe_network docker bridge";
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''${pkgs.docker}/bin/docker network create frappe_network || true'';
    };
  
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
  
      # --- ERPNext Components ---
  
      erpnext-db = {
        image = "mariadb:11.8";
        environment = {
          "MYSQL_ROOT_PASSWORD" = defaultPass;
          "MARIADB_ROOT_PASSWORD" = defaultPass;
        };
        volumes = [ "/var/lib/erpnext/mysql:/var/lib/mysql" ];
        # RAM OPTIMIZATION: Shrink buffers to 128M and limit connections
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
        # RAM OPTIMIZATION: Cap cache to 128mb, evict old data if full
        cmd = [ "redis-server" "--maxmemory" "128mb" "--maxmemory-policy" "allkeys-lru" ];
        extraOptions = [ "--network=frappe_network" ];
      };
  
      erpnext-redis-queue = {
        image = "redis:6.2-alpine";
        volumes = [ "/var/lib/erpnext/redis-queue:/data" ];
        extraOptions = [ "--network=frappe_network" ];
      };
  
      erpnext-init = {
        image = frappeImage;
        dependsOn = [ "erpnext-db" "erpnext-redis-cache" "erpnext-redis-queue" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        extraOptions = [ "--network=frappe_network" ];
        entrypoint = "/bin/bash";
        cmd = [ "-c" ''
          ls -1 apps > sites/apps.txt;
          bench set-config -g db_host erpnext-db;
          bench set-config -gp db_port 3306;
          bench set-config -g redis_cache redis://erpnext-redis-cache:6379;
          bench set-config -g redis_queue redis://erpnext-redis-queue:6379;
          bench set-config -g redis_socketio redis://erpnext-redis-queue:6379;
          bench set-config -gp socketio_port 9000;
          
          if [ ! -d sites/frontend ]; then
            echo "Waiting 10s for DB..."; sleep 10;
            bench new-site frontend \
              --mariadb-user-host-login-scope='%' \
              --admin-password=${defaultPass} \
              --db-root-username=root \
              --db-root-password=${defaultPass} \
              --install-app erpnext;
          fi
        '' ];
      };
  
      erpnext-backend = {
        image = frappeImage;
        dependsOn = [ "erpnext-db" "erpnext-redis-cache" "erpnext-redis-queue" ];
        environment = {
          "DB_HOST" = "erpnext-db";
          "DB_PORT" = "3306";
          "MYSQL_ROOT_PASSWORD" = defaultPass;
          "MARIADB_ROOT_PASSWORD" = defaultPass;
          # RAM OPTIMIZATION: Force minimum worker count to save hundreds of MBs
          "GUNICORN_WORKERS" = "1";
          "GUNICORN_THREADS" = "2";
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
        # RAM OPTIMIZATION: Consolidated 3 workers into 1 container
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
          # RAM OPTIMIZATION: Clamp Node.js memory limit to 128MB
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
    systemd.services."docker-erpnext-init" = {
      after = [ "docker-network-frappe.service" ];
      requires = [ "docker-network-frappe.service" ];
      serviceConfig = {
        Type = lib.mkForce "oneshot";
        RemainAfterExit = lib.mkForce true;
        Restart = lib.mkForce "no";
      };
    };
  };
}