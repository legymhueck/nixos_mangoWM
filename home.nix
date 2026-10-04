{ lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.mango.hmModules.mango
    inputs.noctalia.homeModules.default
  ];

  home.username = "m";
  home.homeDirectory = "/home/m";
  home.stateVersion = "26.05";

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  programs.firefox.enable = true;

  home.packages = with pkgs; [
    (brave.override {
      commandLineArgs = "--password-store=gnome-libsecret";
    })

    bitwarden-desktop
    ente-auth
    github-copilot-cli
    helix
    jetbrains-mono
    liberation_ttf
    mc
    micro
    opencode
    proton-pass
    proton-authenticator
    wl-clipboard
    udisks2
    starship
    vscode
  ];

  fonts.fontconfig.enable = true;

  programs.foot = {
    enable = true;

    settings = {
      main = {
        font = "JetBrains Mono NL:size=13";
      };
    };
  };

  programs.noctalia = {
    enable = true;

    settings = {
      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Catppuccin";
      };

      shell.animation.enabled = false;
      lockscreen.transition = [ ];
    };
  };

  wayland.windowManager.mango = {
    enable = true;
    autostart_sh = "noctalia &";

    settings = {
      xkb_rules_layout = "de";

      animations = 0;
      layer_animations = 0;
      animation_fade_in = 0;
      animation_fade_out = 0;

      bind = [
        "SUPER,d,spawn,noctalia msg panel-toggle launcher"
        "SUPER,s,spawn,noctalia msg panel-toggle control-center"
        "SUPER,comma,spawn,noctalia msg settings-toggle"
        "SUPER,Return,spawn,foot"
        "SUPER,q,killclient,"
        "SUPER+SHIFT,q,quit"
        "SUPER,r,reload_config"
        "SUPER,f,togglefullscreen,"
        "SUPER+SHIFT,space,togglefloating,"
        "SUPER,n,switch_layout"
        "SUPER,Tab,focusstack,next"
        "SUPER,Left,focusdir,left"
        "SUPER,Right,focusdir,right"
        "SUPER,Up,focusdir,up"
        "SUPER,Down,focusdir,down"
        "SUPER+SHIFT,Left,exchange_client,left"
        "SUPER+SHIFT,Right,exchange_client,right"
        "SUPER+SHIFT,Up,exchange_client,up"
        "SUPER+SHIFT,Down,exchange_client,down"
        "NONE,XF86AudioRaiseVolume,spawn,noctalia msg volume-up"
        "NONE,XF86AudioLowerVolume,spawn,noctalia msg volume-down"
        "NONE,XF86AudioMute,spawn,noctalia msg volume-mute"
        "NONE,XF86MonBrightnessUp,spawn,noctalia msg brightness-up"
        "NONE,XF86MonBrightnessDown,spawn,noctalia msg brightness-down"
      ] ++ lib.concatMap (n:
        let k = toString n;
        in [
          "SUPER,${k},view,${k},0"
          "SUPER+ALT,${k},tag,${k},0"
        ]
      ) (lib.range 1 9);
    };
  };
}
