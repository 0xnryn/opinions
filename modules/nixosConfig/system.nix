{ inputs, ... }:
{
  flake.nixosModules.system = { pkgs, config, inputs, ... }: {
    imports = [
      inputs.sops-nix.nixosModules.sops
    ];
    nix.settings = {
      experimental-features = [ "nix-command" "flakes" "pipe-operators" ];
    };
    programs.nix-ld = {
      enable = true;
    };
    nixpkgs.config.allowUnfree = true;
    system.stateVersion = "26.05";
    time.timeZone = "Asia/Kolkata";
    i18n.defaultLocale = "en_US.UTF-8";
    console.keyMap = "us";
    
    services = {
      printing.enable = true;
      pipewire = {
        enable = true;
        pulse.enable = true;
        # ADD THESE THREE LINES:
        alsa.enable = true;
        alsa.support32Bit = true;
        wireplumber.enable = true; # The modern session manager that handles dynamic routing
      };
      openssh.enable = true;

    };
    environment.systemPackages = with pkgs; [
      tree 
      util-linux 
      vim 
      wget 
      curl 
      git 
      gptfdisk 
      htop 
      pciutils 
      home-manager
      cloudflared
      sops
      age
      ssh-to-age
      age-plugin-tpm
      sbctl
    ];
  };
}