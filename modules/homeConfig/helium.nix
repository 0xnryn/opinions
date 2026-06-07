# Notice pkgs is NOT in the top-level arguments
{ inputs, ... }:
{
  flake.homeModules."helium-browser" = { pkgs, ... }: {
    # The inner function receives the correct 'pkgs' from Home Manager
    home.packages = [
      # We use 'inputs' from the outer scope, and 'pkgs' from the inner scope
      inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}