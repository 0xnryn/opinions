{ inputs, config, pkgs, ... }: {

  imports = [
    inputs.cosmic.flakeModules.default
  ];
  # Declare the requirement to the Cosmic Engine
  cosmicage.secrets."cloudflare" = {
    # Systemd reads EnvironmentFiles as root before passing them to the service.
    # Therefore, root can own it, allowing DynamicUser to work flawlessly!
    mode = "0400";
    owner = "root"; 
    group = "root";
  };

  systemd.services.cloudflared-tunnel = {
    description = "Cloudflared Remotely Managed Tunnel";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    
    serviceConfig = {
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run";
      
      # Systemd will read TUNNEL_TOKEN=... from this file and inject it as an env var
      EnvironmentFile = config.age.secrets."cloudflare".path;
      
      Restart = "always";
      RestartSec = "5s";
      
      # Highly recommended for security. Systemd creates an isolated user for this process.
      DynamicUser = true; 
      
      # Additional hardening (optional but recommended for network-facing tunnels)
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };
}