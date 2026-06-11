# opinions/modules/nixosConfig/cosmicnetwork.nix
# # nix run nixpkgs#syncthing -- generate --home ./syncthing-secrets
# cat ./syncthing-secrets/cert.pem
# cat ./syncthing-secrets/key.pem
{ ... }:
{
  flake.nixosModules.cosmicnetwork = { pkgs, config, lib, ... }: 
  let
    # ==========================================
    # 🌐 MESH NETWORK CONFIGURATION
    # ==========================================
    tld = "sudha";            
    meshFolder = "mesh-dns";  
    
    syncPath = "/var/lib/${meshFolder}";
    hostsFile = "${syncPath}/dns.hosts";
    keysFile = "${syncPath}/syncthing-pubkeys.txt";
    fullDomain = "${config.networking.hostName}.${tld}";
  in {
    # 1. ENFORCE OS DNS ROUTING
    # This safely merges with any networking config you put in your machine file
    networking.nameservers = [ "127.0.0.2" ];
    networking.networkmanager.dns = "none";

    # 2. SYNCTHING ENGINE
    services.syncthing = {
      enable = true;
      user = "root"; 
      dataDir = "/var/lib/syncthing";
      configDir = "/var/lib/syncthing/.config";
      
      # Automatically fetch secrets from the specific machine's SOPS config
      cert = config.sops.secrets."syncthing_cert".path;
      key = config.sops.secrets."syncthing_key".path;
      
      overrideDevices = false; 
      overrideFolders = false; 
      guiAddress = "127.0.0.1:8384";

      settings = {
        options = {
          listenAddresses = [ "tcp6://[::]:22000" ];
          localAnnounceEnabled = false; globalAnnounceEnabled = false;
          relaysEnabled = false; natEnabled = false;
        };            
        
        # You can leave your master laptop ID hardcoded here as the "seed" node for the entire fleet
        devices = {
          "laptop" = { id = "CWN4LAU-3M5REFQ-YMEGNOZ-JFUTSPX-FL7C4CB-QZDKDS7-KKWDJ7S-WF4RBQ6"; };
        };
        folders = {
          "${meshFolder}" = {
            id = "dns"; 
            path = syncPath;
            type = "sendreceive"; 
            devices = [ "laptop" ]; 
            versioning = { type = "simple"; params.keep = "5"; };
          };
        };
      };
    };

    # 3. DYNAMIC IP INJECTION (BOOTSTRAP)
    systemd.services.bootstrap-mesh-dns = {
      description = "Inject dynamic Yggdrasil IP into Syncthing DNS";
      bindsTo = [ "sys-subsystem-net-devices-ygg0.device" ];
      after   = [ "sys-subsystem-net-devices-ygg0.device" ];
      before  = [ "syncthing.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "inject-mesh-dns" ''
          mkdir -p ${syncPath}
          touch "${hostsFile}"

          if [ ! -f "${keysFile}" ]; then
            echo "# Format: [Device-ID]                       [Hostname]" > "${keysFile}"
          fi

          YGG_IP=$(${pkgs.iproute2}/bin/ip -6 -o addr show dev ygg0 scope global | ${pkgs.gawk}/bin/awk '{print $4}' | cut -d/ -f1 | head -n 1)

          ${pkgs.gnused}/bin/sed -i "/${fullDomain}/d" "${hostsFile}"
          echo "$YGG_IP    ${fullDomain}" >> "${hostsFile}"
          
          chown -R root:root ${syncPath}
          chmod 755 ${syncPath}
          chmod 644 "${hostsFile}"
          chmod 644 "${keysFile}"
        '';
      };
    };

    # 4. THE GATEKEEPER DAEMON
    systemd.paths.syncthing-pubkeys-watcher = {
      wantedBy = [ "multi-user.target" ];
      pathConfig.PathModified = keysFile;
    };

    systemd.services.syncthing-pubkeys-watcher = {
      description = "Dynamically inject new Syncthing public keys from the P2P registry";
      after = [ "syncthing.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "inject-syncthing-keys" ''
          ST_HOME="/var/lib/syncthing/.config"
          sleep 2 
          while read -r id name; do
            [[ $id =~ ^#.*$ ]] || [[ -z $id ]] && continue
            ${pkgs.syncthing}/bin/syncthing cli --home="$ST_HOME" config devices add --device-id="$id" --name="$name" || true
            ${pkgs.syncthing}/bin/syncthing cli --home="$ST_HOME" config folders "dns" devices add --device-id="$id" || true
          done < ${keysFile}
        '';
      };
    };

    # 5. MASTERLESS COREDNS
    services.coredns = {
      enable = true;
      config = ''
        .:53 {
            bind 127.0.0.2
            hosts ${hostsFile} ${tld} {
                fallthrough
            }
            forward . 1.1.1.1 1.0.0.1
            cache 3600
            reload 0s
            log
            errors
        }
      '';
    };
  };
}