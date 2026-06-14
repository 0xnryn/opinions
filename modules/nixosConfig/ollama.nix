{ ... }:
{
  # flake.nixosModules.ollama_cuda = { pkgs, ... }:
  # {
  #   services.ollama = {
  #     enable = true;
  #     package = pkgs.ollama-cuda; 
  #   };
  # };
  # 
  flake.nixosModules.ollama_cuda = { pkgs, config, ... }:
    {
      services.ollama = {
        enable = true;
        
        # 1. Use the native NixOS option instead of the package override
        acceleration = "cuda"; 
        
        environmentVariables = {
          # 2. Force wake the Nvidia GPU from fine-grained sleep
          __NV_PRIME_RENDER_OFFLOAD = "1";
          __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          __VK_LAYER_NV_optimus = "NVIDIA_only";
          
          # 3. Explicitly disable the AMD iGPU compute to prevent the llama-server split crash
          HIP_VISIBLE_DEVICES = "-1";
          ROCR_VISIBLE_DEVICES = "-1";
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