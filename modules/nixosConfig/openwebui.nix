{ ... }:
{
  flake.nixosModules.nryn-openwebui = { ... }: {
    services.open-webui = {
      enable = true;
      
      host = "127.0.0.1"; 
      port = 7070;
      
      environment = {
        SCARF_NO_ANALYTICS = "True";
        DO_NOT_TRACK = "True";
        ANONYMIZED_TELEMETRY = "False";
        ENABLE_SIGNUP = "True"; 
        
        # --- Disable Local Machine Learning (AVX Bypass) ---
        # This prevents PyTorch/ONNX from loading and crashing your CPU
        ENABLE_RAG_LOCAL_MODELS = "False";
        ENABLE_RAG_WEB_SEARCH = "False";
        RAG_EMBEDDING_ENGINE = ""; 
        
        # Optional: Explicitly disable image generation if you don't use it
        ENABLE_IMAGE_GENERATION = "False";
      };
    };
  };
}