{ lib, inputs, ... }:
let
  frappeImage = "frappe/erpnext:v16.18.3";
  frappeNetwork = "frappe_network";
in
{
  flake.nixosModules.erpnext = { config, pkgs, ... }: {
    
    imports = [ inputs.sops-nix.nixosModules.sops ];

    sops = {
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      secrets."erpnext.env" = {
        sopsFile = ../secrets/erpnext.env;
        format = "dotenv";
      };
    };

    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";

    # Create the docker bridge network before any container starts
    systemd.services."docker-network-frappe" = {
      description = "Create frappe_network docker bridge network";
      before = [
        "docker-erpnext-db.service"
        "docker-erpnext-backend.service"
        "docker-erpnext-frontend.service"
        "docker-erpnext-websocket.service"
        "docker-erpnext-queue-short.service"
        "docker-erpnext-queue-long.service"
        "docker-erpnext-scheduler.service"
        "docker-erpnext-redis-cache.service"
        "docker-erpnext-redis-queue.service"
      ];
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if ! /run/current-system/sw/bin/docker network inspect ${frappeNetwork} > /dev/null 2>&1; then
          /run/current-system/sw/bin/docker network create --driver bridge ${frappeNetwork}
        fi
      '';
    };

    # Prepare host directories with correct ownership
    systemd.services."erpnext-init-dirs" = {
      description = "Initialize ERPNext host directories";
      before = [
        "docker-erpnext-backend.service"
        "docker-erpnext-frontend.service"
      ];
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p /var/lib/erpnext/sites
        mkdir -p /var/lib/erpnext/logs
        mkdir -p /var/lib/erpnext/mysql
        mkdir -p /var/lib/erpnext/redis-queue
        
        # Create apps.txt if it doesn't exist
        if [ ! -f /var/lib/erpnext/sites/apps.txt ]; then
          echo -e "frappe\nerpnext" > /var/lib/erpnext/sites/apps.txt
        fi
        
        chown -R 1000:1000 /var/lib/erpnext/sites
        chown -R 1000:1000 /var/lib/erpnext/logs
      '';
    };

    virtualisation.oci-containers.containers = {

      erpnext-db = {
        image = "mariadb:11.8";
        networks = [ frappeNetwork ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
        volumes = [ "/var/lib/erpnext/mysql:/var/lib/mysql" ];
        cmd = [
          "--character-set-server=utf8mb4"
          "--collation-server=utf8mb4_unicode_ci"
          "--skip-character-set-client-handshake"
        ];
        extraOptions = [
          "--health-cmd=healthcheck.sh --connect --innodb_initialized"
          "--health-start-period=5s"
          "--health-interval=5s"
          "--health-timeout=5s"
          "--health-retries=5"
        ];
      };

      erpnext-redis-cache = {
        image = "redis:6.2-alpine";
        networks = [ frappeNetwork ];
      };

      erpnext-redis-queue = {
        image = "redis:6.2-alpine";
        networks = [ frappeNetwork ];
        volumes = [ "/var/lib/erpnext/redis-queue:/data" ];
      };

      erpnext-backend = {
        image = frappeImage;
        networks = [ frappeNetwork ];
        dependsOn = [ "erpnext-db" "erpnext-redis-cache" "erpnext-redis-queue" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
      };

      erpnext-websocket = {
        image = frappeImage;
        networks = [ frappeNetwork ];
        dependsOn = [ "erpnext-backend" ];
        cmd = [ "node" "/home/frappe/frappe-bench/apps/frappe/socketio.js" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
      };

      erpnext-frontend = {
        image = frappeImage;
        networks = [ frappeNetwork ];
        dependsOn = [ "erpnext-backend" "erpnext-websocket" ];
        cmd = [ "nginx-entrypoint.sh" ];
        ports = [ "8080:8080" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
      };

      erpnext-queue-short = {
        image = frappeImage;
        networks = [ frappeNetwork ];
        dependsOn = [ "erpnext-backend" ];
        cmd = [ "bench" "worker" "--queue" "short,default" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
      };

      erpnext-queue-long = {
        image = frappeImage;
        networks = [ frappeNetwork ];
        dependsOn = [ "erpnext-backend" ];
        cmd = [ "bench" "worker" "--queue" "long,default,short" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
      };

      erpnext-scheduler = {
        image = frappeImage;
        networks = [ frappeNetwork ];
        dependsOn = [ "erpnext-backend" ];
        cmd = [ "bench" "schedule" ];
        volumes = [
          "/var/lib/erpnext/sites:/home/frappe/frappe-bench/sites"
          "/var/lib/erpnext/logs:/home/frappe/frappe-bench/logs"
        ];
        environmentFiles = [ config.sops.secrets."erpnext.env".path ];
      };

    };
  };
}