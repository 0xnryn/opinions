{ ... }:
{
  flake.nixosModules.ollama_cuda = { pkgs, ... }:
  {
    services.ollama = {
      enable = true;
      package = pkgs.ollama-cuda; 
    };
  };

  { ... }:
  {
    flake.nixosModules.ollama_amd = { pkgs, ... }:
    {
      services.ollama = {
        enable = true;
        package = pkgs.ollama-vulkan; 
        
        environmentVariables = {
          # Force Vulkan to ONLY see the AMD iGPU (GPU0)
          # This completely hides the 4GB RTX 3050 (GPU1) from Ollama
          GGML_VK_VISIBLE_DEVICES = "0"; 
        };
      };
    };
  }
  
  flake.nixosModules.ollama = { pkgs, ... }:
  {
    services.ollama = {
      enable = true;
    };
  };
}