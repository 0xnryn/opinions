{ ... }:
{
  flake.nixosModules.ollama_cuda = { pkgs, ... }:
  {
    services.ollama = {
      enable = true;
      package = pkgs.ollama-cuda;
    };
  };

  flake.nixosModules.ollama = { pkgs, ... }:
  {
    services.ollama = {
      enable = true;
    };
  };
}