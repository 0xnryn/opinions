{
  flake.nixosModules.protoplast_tb = { config, pkgs, ... }:

  {
    virtualisation.oci-containers = {
      backend = "docker";
      
      containers."protoplast_tb_postgres" = {
        image = "protoplaststudio/tb-postgres:latest"; 
        
        ports = [
          # Bind strictly to localhost for Cloudflare Tunnel. 
          # No public ports exposed. HTTP only.
          "127.0.0.1:9090:9090" 
        ];

        environment = {
          # --- DO NOT REMOVE: DATABASE SURVIVAL SETTINGS ---
          # These cannot be easily configured in the CE UI. 
          # Without these, your disk will eventually fill to 100%.
          "SQL_TTL_TELEMETRY_ENABLED" = "true";
          "SQL_TTL_TELEMETRY_TTL" = "2592000";     # 30 days
          "SQL_TTL_ERROR_EVENTS_TTL" = "604800";   # 7 days
          "SQL_TTL_DEBUG_EVENTS_TTL" = "604800";   # 7 days
          "SQL_TTL_AUDIT_LOGS_TTL" = "2592000";    # 30 days
        };
        
        volumes = [
          "/var/lib/thingsboard:/data"
        ];
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/thingsboard 0775 799 799 -" 
    ];

    # HTTP-only via Cloudflare. Zero external firewall ports needed.
    networking.firewall.allowedTCPPorts = [];
    networking.firewall.allowedUDPPorts = []; 
  };
}