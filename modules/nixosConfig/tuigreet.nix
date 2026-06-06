{ ... }:
{
  flake.nixosModules.tuigreet = { pkgs, ... }: {
    
    # Inject tuigreet settings into the existing greetd service
    services.greetd.settings = {
      default_session = {
        # FIX: Dropped the 'greetd.' prefix to silence the deprecation warning
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --cmd niri";
        user = "greeter";
      };
    };

    environment.systemPackages = with pkgs; [
      tuigreet
    ];
  };
}