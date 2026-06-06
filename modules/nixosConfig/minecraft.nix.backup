{ inputs, lib, pkgs, ... }:
{
  # Playit Agent Module
  flake.nixosModules.playit = { ... }: {
    # The NixOS way to add binary caches (instead of nixConfig)
    nix.settings = {
      substituters = [ "https://playit-nixos-module.cachix.org" ];
      trusted-public-keys = [ "playit-nixos-module.cachix.org-1:22hBXWXBbd/7o1cOnh+p0hpFUVk9lPdRLX3p5YSfRz4=" ];
    };

    # Import the module
    imports = [ inputs.playit-nixos-module.nixosModules.default ]; 
    
    services.playit = {
      enable = true;
      # Pointing directly to the generated secret file
      secretPath = "/home/sudha/.config/playit_gg/playit.toml"; 
    };
  };

  # Minecraft Server Module
  minecraft = { pkgs, ... }: {
    services.minecraft-server = {
      enable = true;
      eula = true; 
      openFirewall = true; 
      package = pkgs.minecraft-server; 
      
      declarative = true; # <-- ADD THIS LINE

      serverProperties = {
        server-port = 25565;
        online-mode = false; 
        motd = "NixOS Minecraft Server";
      };
    };
  };
}