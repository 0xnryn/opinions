{ ... }:
{
  flake.nixosModules.ollama_cuda = { pkgs, ... }:
  {
    services.ollama = {
        enable = true;
        
        # Explicitly use the CUDA-compiled package instead of the acceleration flag
        package = pkgs.ollama-cuda; 
        
        environmentVariables = {
          CUDA_VISIBLE_DEVICES = "0";
          GGML_VK_VISIBLE_DEVICES = "0";
        };
      };
  };

  flake.nixosModules.ollama = { pkgs, ... }:
  {
    services.ollama = {
      enable = true;
    };
  };
}