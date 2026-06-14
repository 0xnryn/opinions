{ config, lib, ... }:

with lib;

let
  # You define your custom namespace path here
  cfg = config.cosmic.sudha.opinions.services.yggdrasil;
in
{
  # The options MUST match the exact path you used in 'cfg'
  options.cosmic.sudha.opinions.services.yggdrasil = {
    enable = mkEnableOption "Enable Sudha's opinionated Yggdrasil mesh (Cosmic Engine)";
    
    privateKeyPath = mkOption { 
      type = types.str; 
      description = "Absolute path to the Yggdrasil private key";
    };
  };

  # Now cfg.enable and cfg.privateKeyPath will work flawlessly
  config = mkIf cfg.enable {
    
    networking.firewall = {
      allowedTCPPorts = [ 53535 ];
      allowedUDPPorts = [ 53535 ];
    };

    services.yggdrasil = {
      enable = true;
      openMulticastPort = true;
      settings = {
        IfName = "ygg0";
        Listen = [ "tcp://0.0.0.0:53535" ];
        PrivateKeyPath = cfg.privateKeyPath; 
        NodeInfoPrivacy = true;
        Peers = [
          #india
          "tls://ins.8px.sk:4321"
          "quic://ins.8px.sk:4321"
          #hongkong
          "tcp://ygg5.mk16.de:1337?key=0000009611ae5391dc0aceea9f3fa6a0dc1279f4306059339e84bfb8b74d2f9b"
          "tls://ygg5.mk16.de:1338?key=0000009611ae5391dc0aceea9f3fa6a0dc1279f4306059339e84bfb8b74d2f9b"
          "quic://ygg5.mk16.de:1339?key=0000009611ae5391dc0aceea9f3fa6a0dc1279f4306059339e84bfb8b74d2f9b"
          "ws://ygg5.mk16.de:1340?key=0000009611ae5391dc0aceea9f3fa6a0dc1279f4306059339e84bfb8b74d2f9b"
          #singapore
          "tls://asia.deinfra.org:15015"
          "quic://asia.deinfra.org:15015"
          "tcp://yg-sin.magicum.net:23901"
          "tls://yg-sin.magicum.net:23900"
        ];
        MulticastInterfaces = [
          {
            Regex = ".*";  
            Beacon = true; 
            Listen = true; 
            Port = 9001;   
          }
        ];
      };
    };
  };
}