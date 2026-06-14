{ ... }:
{
  flake.nixosModules.sudha-openwebui = { ... }: {
    services.open-webui = {
      enable = true;
      host = "0.0.0.0";
      port = 8080;
      environment = {
        SCARF_NO_ANALYTICS = "True";
        DO_NOT_TRACK = "True";
        ANONYMIZED_TELEMETRY = "False";
      };
    };
  };
}