{ ... }: 
{
  flake.nixosModules."git-access-tokens" = { config, ... }: {
    cosmicage.secrets."git-access-tokens" = {
      mode = "0440";
      owner = "root"; 
      group = "wheel";
    };
    nix.extraOptions = ''
      !include ${config.age.secrets."git-access-tokens".path}
    '';
  };
}