{ ... }:
{
  flake.nixosModules.gnome = { pkgs, ... }:
  {
    services = {
      # 1. Enable the bare GNOME Desktop Environment
      desktopManager.gnome.enable = true;
      
      # 1. Enable GDM (GNOME Display Manager)
      displayManager.gdm = {
        enable = true;
      };

      # 2. Strip down all the bloatware (games, email, maps, etc.)
      gnome = {
        core-apps.enable = false;
        core-developer-tools.enable = false;
        games.enable = false;
      };
    };

    # 2. Further strip any lingering default packages
    environment.gnome.excludePackages = with pkgs; [
      gnome-tour
      gnome-user-docs
    ];

    environment.systemPackages = with pkgs; [
      # Adding Tweaks as it is essentially mandatory for configuring 
      # a bare GNOME setup once you are logged in.
      nautilus
      gnome-tweaks
      gnome-console
      impression
      # Useful Wayland utilities you already had in Plasma
      wayland-utils
      wl-clipboard
    ];

    # Ensure Wayland compatibility for Electron apps
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
  };
}
