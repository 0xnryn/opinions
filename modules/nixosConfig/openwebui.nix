{ ... }:
{
  flake.nixosModules.openwebui = { ... }: {
    services.open-webui = {
      enable = true;
      port = 8080;
      
      environment = {
        OLLAMA_BASE_URL = "http://127.0.0.1:11434";
        ENABLE_OPENAI_API = "False";
        SCARF_NO_ANALYTICS = "True";
        DO_NOT_TRACK = "True";
        ANONYMIZED_TELEMETRY = "False";
        WEBUI_AUTH = "False";

        # 5. STT (Whisper) Hardware Acceleration
        WHISPER_MODEL = "base.en";
        WHISPER_LANGUAGE = "en";
        WHISPER_MULTILINGUAL = "False";
        
        # MOVE TO NVIDIA GPU
        WHISPER_DEVICE = "cuda";
        
        # CRITICAL: Compress to fit in the remaining 500MB of VRAM
        WHISPER_COMPUTE_TYPE = "int8"; 
      };
    };
  };
}