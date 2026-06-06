{ lib, inputs, ... }:
{
  flake.nixosModules.cloudflared = { config, pkgs, ... }: {
    
    # 1. Import the sops-nix module from your flake inputs
    imports = [ inputs.sops-nix.nixosModules.sops ];

    # 2. Configure SOPS
    sops = {
      # Tell sops-nix to use the server's SSH key to unlock the file
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      
      # Declare the specific secret file
      secrets."cloudflare.env" = {
        sopsFile = ../secrets/cloudflare.env;
        format = "dotenv";
      };
    };

    # 3. Create the robust Cloudflared Service
    systemd.services.cloudflared-tunnel = {
      description = "Cloudflared Remotely Managed Tunnel";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      
      serviceConfig = {
        # The main executable
        ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run";
        
        # INJECT THE SECRET HERE: config.sops.secrets."name".path points to the decrypted RAM disk
        EnvironmentFile = config.sops.secrets."cloudflare.env".path;
        
        Restart = "always";
        RestartSec = "5s";
        DynamicUser = true; 
      };
    };
  };
}