{ ... }:
{
  flake.nixosModules.helm = { pkgs, ... }:
  {
    environment.systemPackages = with pkgs; [
      # The actual Helm binary (Helm v3)
      kubernetes-helm
      
      # Helm relies on your local kubeconfig to authenticate. 
      # You almost always want kubectl installed alongside it.
      kubectl 
    ];
  };
}