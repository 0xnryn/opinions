{ ... }:
{
  flake.nixosModules.ollama_cuda = { pkgs, ... }:
  {
    services.ollama = {
      enable = true;
      acceleration = "cuda";
      
      # Force Ollama to ignore the integrated graphics and only use the dGPU
      environmentVariables = {
        CUDA_VISIBLE_DEVICES = "0";
        
        # If your system ever falls back to Vulkan, lock that too:
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