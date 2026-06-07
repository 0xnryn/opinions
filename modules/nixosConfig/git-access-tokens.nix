{ ... }: 
{
  flake.nixosModules."git-access-tokens" = { config, lib, ... }: {
    
    # Use lib.mkDefault so any machine can easily override these settings
    cosmicage.secrets."git-access-tokens" = {
      mode  = lib.mkDefault "0440";
      owner = lib.mkDefault "root"; 
      group = lib.mkDefault "wheel";
    };

    nix.extraOptions = ''
      !include ${config.age.secrets."git-access-tokens".path}
    '';
  };
}