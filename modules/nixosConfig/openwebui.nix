{ ... }:
{
  flake.nixosModules.nryn-openwebui = { ... }: {
    services.open-webui = {
      enable = true;
      
      # Bind to localhost instead of 0.0.0.0
      # Since Cloudflare Tunnel will route traffic here, binding to 127.0.0.1 
      # ensures no one can bypass Cloudflare and hit your server's IP directly on port 7070.
      host = "127.0.0.1"; 
      port = 7070;
      
      environment = {
        SCARF_NO_ANALYTICS = "True";
        DO_NOT_TRACK = "True";
        ANONYMIZED_TELEMETRY = "False";
        
        # Controls whether new users can register. 
        # Leave as "True" to let others make accounts, or change to "False" 
        # AFTER you create your admin account to lock it down.
        ENABLE_SIGNUP = "True"; 
      };
    };
  };
}