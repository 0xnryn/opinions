{ ... }: 
{
  flake.nixosModules."git-access-tokens" = { config, lib, ... }: {

    # In sudhalaptop.nix
    cosmicage.secrets."git-access-tokens".file = "git-access-tokens.age";
    
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