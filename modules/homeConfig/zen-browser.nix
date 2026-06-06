# Notice pkgs is REMOVED from this top line
{ inputs, ... }:
{
  flake.homeModules."zen-browser" = { pkgs, ... }: {
    home.packages = [
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
