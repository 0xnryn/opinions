{ ... }: 
{
  flake.nixosModules."hostssh" = { lib, ... }: {
    
    # We use a generic name so ANY machine can use this module.
    cosmicage.secrets."hostssh" = {
      
      # We purposefully DO NOT define 'file' here, because it changes per machine!
      
      # Set the standard SSH daemon path and permissions as soft defaults
      path  = lib.mkDefault "/etc/ssh/ssh_host_ed25519_key"; 
      mode  = lib.mkDefault "0600";
      owner = lib.mkDefault "root";
    };
  };
}