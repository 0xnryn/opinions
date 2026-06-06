{ self, inputs, ... }: 
{
  # ==========================================
  # 1. THE NATIVE COMPILER (perSystem)
  # Writes raw KDL to the Nix Store and wraps the binary
  # ==========================================
  perSystem = { pkgs, lib, ... }: 
    let
      # 1. Define your exact, raw KDL configuration
      myNiriConfig = pkgs.writeText "niri-config.kdl" ''
        // --- GLOBAL ENVIRONMENT VARIABLES ---
        environment {
            GTK_USE_PORTAL "1"
            NIXOS_OZONE_WL "1"
        }

        // --- RUNTIME PIPELINE (AUTOSTART) ---
        spawn-at-startup "${lib.getExe pkgs.noctalia-shell}"
        spawn-at-startup "systemctl" "--user" "import-environment" "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP" "NIXOS_OZONE_WL" "GTK_USE_PORTAL"
        spawn-at-startup "systemctl" "--user" "start" "graphical-session.target"

        // --- INPUT TRACKING ---
        input {
            touchpad {
                tap
                dwt
                natural-scroll
            }
        }

        // --- THE VANILLA KEYBINDING MATRIX ---
        binds {
            Mod+T { spawn "zeditor"; }
            Mod+B { spawn "zen"; }
            Mod+Space { spawn "${lib.getExe pkgs.noctalia-shell}" "ipc" "call" "launcher" "toggle"; }
            
            Mod+Comma { consume-window-into-column; }
            Mod+Period { expel-window-from-column; }
            
            Mod+H { focus-column-left; }
            Mod+L { focus-column-right; }
            Mod+K { focus-window-or-monitor-up; }
            Mod+J { focus-window-or-monitor-down; }

            Mod+Shift+H { move-column-left; }
            Mod+Shift+L { move-column-right; }
            Mod+Shift+K { move-window-up; }
            Mod+Shift+J { move-window-down; }

            XF86AudioMute { spawn "pamixer" "-t"; }
            XF86AudioLowerVolume { spawn "pamixer" "-d" "5"; }
            XF86AudioRaiseVolume { spawn "pamixer" "-i" "5"; }
            XF86AudioMicMute { spawn "pamixer" "--default-source" "-t"; }
            XF86MonBrightnessDown { spawn "brightnessctl" "set" "10%-"; }
            XF86MonBrightnessUp { spawn "brightnessctl" "set" "+10%"; }
            XF86AudioPlay { spawn "playerctl" "play-pause"; }
            XF86AudioNext { spawn "playerctl" "next"; }
            XF86AudioPrev { spawn "playerctl" "previous"; }

            Mod+Q { close-window; }
            Mod+Shift+E { quit skip-confirmation=true; }

            // SCREENSHOTS
            // Print Screen: Capture entire screen to clipboard
            Print { spawn "grim" "- | wl-copy"; }
            // Shift+Print Screen: Select area to capture to clipboard
            Shift+Print { spawn "bash" "-c" "grim -g \"$(slurp)\" - | wl-copy"; }
        }
      '';
    in {
      # 2. Build the immutable Niri binary using native Nix tools
      packages.myNiri = pkgs.symlinkJoin {
        name = "niri-wrapped";
        paths = [ pkgs.niri ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/niri \
            --add-flags "--config ${myNiriConfig}"
        '';
        # FIX: Tell the OS that this package is a valid login session
        passthru.providedSessions = [ "niri" ];
      };
    };

  # ==========================================
  # 2. THE SYSTEM INTEGRATION (nixosModules)
  # ==========================================
  flake.nixosModules.niri = { pkgs, ... }: {
    
    programs.niri = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.myNiri;
    };

    # THE DESKTOP SHELL INTEGRATION (Replaces Home Manager)
    environment.systemPackages = with pkgs; [
      noctalia-shell
      pamixer
      brightnessctl
      playerctl
      grim        # Captures the screenshot
      slurp       # Allows you to select the area
      wl-clipboard # Copies the image to your clipboard
    ];
    
    programs.dconf.enable = true;
    services.gvfs.enable = true; 
    services.tumbler.enable = true; 

    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
      ];
      config.niri = {
        default = [ "gnome" "gtk" ];
      };
    };

    systemd.user.services.polkit-kde-authentication-agent-1 = {
      description = "polkit-kde-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };
}