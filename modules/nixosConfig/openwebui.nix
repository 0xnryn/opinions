{ ... }:
{
  flake.nixosModules.openwebui = { ... }: {
    services.open-webui = {
      enable = true;
      port = 8080;
      environment = {
        SCARF_NO_ANALYTICS = "True";
        DO_NOT_TRACK = "True";
        ANONYMIZED_TELEMETRY = "False";
      };
    };
  };
}