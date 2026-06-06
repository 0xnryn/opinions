{ ... }:
{
  flake.nixosModules.greetd = { pkgs, ... }: {
    
    # 1. Enable the base greetd daemon
    services.greetd = {
      enable = true;
    };

    # 2. Enable Polkit (Mandatory for Wayland session authentication)
    security.polkit.enable = true;

    # 3. Silent Boot (Prevents kernel logs from bleeding into the TUI)
    boot.consoleLogLevel = 3;
    boot.kernelParams = [ "quiet" "udev.log_level=3" ];

    # 4. Base Wayland utilities
    environment.systemPackages = with pkgs; [
      wayland-utils
      wl-clipboard
    ];
  };
}