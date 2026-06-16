{ ... }:
{
  flake.nixosModules.sudha-gnunet = { config, pkgs, lib, ... }: 
  let
    cfg = config.cosmic.gnunet;
    egoDir = "/var/lib/gnunet/.local/share/gnunet/identity/egos";
  in {
    options.cosmic.gnunet = {
      enable = lib.mkEnableOption "Cosmic Gnunet Opinion";
      identityName = lib.mkOption {
        type = lib.types.str;
        default = "root_zone";
        description = "The name of the GNUnet identity ego (your master zone name).";
      };
      sopsKeyName = lib.mkOption {
        type = lib.types.str;
        default = "gnunetkey";
        description = "The name of the SOPS secret containing the Gnunet identity key.";
      };
    };
    config = lib.mkIf cfg.enable {
      services.gnunet.enable = true;
      environment.systemPackages = [ pkgs.gnunet ];
      networking.firewall = {
        allowedTCPPorts = [ 2086 ];
        allowedUDPPorts = [ 2086 ];
      };
      system.nssModules = [ pkgs.gnunet ];
      
      sops.secrets.${cfg.sopsKeyName} = {
        owner = "gnunet";
        group = "gnunet";
      };

      systemd.services.gnunet.preStart = lib.mkAfter ''
        mkdir -p ${egoDir}
        chown -R gnunet:gnunet /var/lib/gnunet/.local
        if [ -f ${config.sops.secrets.${cfg.sopsKeyName}.path} ]; then
          ln -sf ${config.sops.secrets.${cfg.sopsKeyName}.path} ${egoDir}/${cfg.identityName}
        fi
      '';
    };
  };
}