{ ... }:
{
  flake.nixosModules.ollama_cuda = { pkgs, ... }:
  {
    services.ollama = {
      enable = true;
      
      # Explicitly use the CUDA-compiled package instead of the acceleration flag
      package = pkgs.ollama-cuda; 
      
      environmentVariables = {
        # Keep your existing CUDA lock
        CUDA_VISIBLE_DEVICES = "0";
        
        # Add the fixes from the GitHub issue
        OLLAMA_LLM_LIBRARY = "cuda";
        OLLAMA_IGPU_ENABLE = "0";
        OLLAMA_VULKAN = "false";
        HSA_OVERRIDE_GFX_VERSION = "";
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