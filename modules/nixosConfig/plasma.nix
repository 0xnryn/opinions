{ ... }:
{
  flake.nixosModules.plasma = { pkgs, ... }:
  {
    services = {
      desktopManager.plasma6.enable = true;
      displayManager.sddm = {
        enable = true;
        wayland.enable = true;
      };
    };

    systemd.coredump.enable = true;

    # 1. The KDE Connect Fix (Firewall handling)
    programs.kdeconnect.enable = true;

    # 2. The GTK Bridge (State saving for non-KDE apps)
    programs.dconf.enable = true;

    # 3. The Bloat Purge (Strip unwanted default KDE apps)
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      discover    # KDE software center (useless on NixOS)
    ];

    environment.systemPackages = with pkgs; [
      # Core KDE Utilities
      kdePackages.plasma-browser-integration
      kdePackages.kcalc
      kdePackages.kcharselect
      kdePackages.kcolorchooser
      kdePackages.kolourpaint
      kdePackages.ksystemlog
      kdePackages.sddm-kcm
      kdePackages.ktorrent
      kdePackages.isoimagewriter
      kdePackages.partitionmanager
      kdePackages.filelight
      
      # Development & Differencing
      kdiff3

      # Non-KDE graphical & Wayland packages
      hardinfo2
      wayland-utils
      wl-clipboard
    ];

    environment.sessionVariables = {
      # Forces Chromium/Electron apps to use native Wayland
      NIXOS_OZONE_WL = "1";
    };
  };
  
  flake.homeModules.plasma = { config, pkgs, ... }:{
    home.activation.refreshKDEAppMenu = config.lib.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental || true
    '';
  };
}