{ inputs, ... }:
{
  flake.homeModules."helium-browser" = { pkgs, ... }: {
    home.packages = [
      inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default
      
      # 1. Install the actual native messaging host package for KDE
      # Use pkgs.plasma-browser-integration if you are still on Plasma 5
      pkgs.kdePackages.plasma-browser-integration 
    ];

    # 2. Manually link the manifest so your custom browser can find it.
    # Assuming Helium is a Chromium-based browser:
    home.file.".config/helium/NativeMessagingHosts/org.kde.plasma.browser_integration.json".source =
      "${pkgs.kdePackages.plasma-browser-integration}/etc/chromium/native-messaging-hosts/org.kde.plasma.browser_integration.json";

    # NOTE: If Helium is a Firefox-based browser instead, you would use this path:
    # home.file.".mozilla/native-messaging-hosts/org.kde.plasma.browser_integration.json".source =
    #   "${pkgs.kdePackages.plasma-browser-integration}/lib/mozilla/native-messaging-hosts/org.kde.plasma.browser_integration.json";
  };
}