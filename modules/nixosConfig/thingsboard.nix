{
  flake.nixosModules.protoplast_tb_postgres = { config, pkgs, ... }:
  {
    virtualisation.oci-containers = {
      backend = "docker";
      containers."protoplast_tb_postgres" = {
        image = "protoplaststudio/tb-postgres:latest"; 
        ports = [
          "127.0.0.1:9090:9090" 
        ];
        environment = {
          "SQL_TTL_TELEMETRY_ENABLED" = "true";
          "SQL_TTL_TELEMETRY_TTL" = "2592000";     # 30 days
          "SQL_TTL_ERROR_EVENTS_TTL" = "604800";   # 7 days
          "SQL_TTL_DEBUG_EVENTS_TTL" = "604800";   # 7 days
          "SQL_TTL_AUDIT_LOGS_TTL" = "2592000";    # 30 days
        };
        volumes = [
          # 1. Core Data: Holds the PostgreSQL database, extensions, and configs
          "/var/lib/thingsboard/data:/data"
          # 2. Diagnostics: Holds persistent application logs for debugging
          "/var/lib/thingsboard/logs:/var/log/thingsboard"
        ];
      };
    };
    systemd.tmpfiles.rules = [
      "d /var/lib/thingsboard/data 0775 799 799 -" 
      "d /var/lib/thingsboard/logs 0775 799 799 -" 
    ];
    # HTTP-only via Cloudflare. Zero external firewall ports needed.
    networking.firewall.allowedTCPPorts = [];
    networking.firewall.allowedUDPPorts = []; 
  };
}