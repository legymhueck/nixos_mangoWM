{ config, lib, pkgs, ... }:

let
  scriptDir = ./mango/scripts/.local/share/scripts;
  archOnlyScripts = [
    "aur_check.sh"
    "fonts_uninstall.sh"
    "gsmartcontrol-wayland-fix.sh"
    "srcinfo-update.sh"
    "srcinfo_update.sh"
    "yay-build.sh"
    "yay_build.sh"
  ];
  userScripts = lib.filterAttrs
    (name: kind: kind == "regular" && !(builtins.elem name archOnlyScripts))
    (builtins.readDir scriptDir);
in
{
  home.packages = with pkgs; [
    adw-gtk3
    adwaita-icon-theme
    adwaita-qt
    alacritty
    alsa-oss
    audacity
    blanket
    btrfs-assistant
    cava
    celluloid
    cmatrix
    doublecmd
    dvdbackup
    fzf
    flameshot
    ghostty
    gimp
    gspell
    grim
    gst_all_1.gst-libav
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-ugly
    handbrake
    hunspell
    hunspellDicts.de_DE
    hunspellDicts.en_US
    hyphen
    hyphenDicts.de_DE
    hyphenDicts.en_US
    ispell
    inter
    kdePackages.dolphin
    kdePackages.dolphin-plugins
    kdePackages.breeze-icons
    kdePackages.kdeconnect-kde
    kdePackages.kdenlive
    kdePackages.kdenetwork-filesharing
    kdePackages.kimageformats
    kdePackages.okular
    kdePackages.partitionmanager
    gtkspell3
    kitty
    libmypaint
    libreoffice
    librewolf
    meld
    mpv
    mplayer
    mypaint
    mypaint-brushes
    nautilus
    networkmanagerapplet
    nuspell
    nwg-look
    obsidian
    pavucontrol
    qt6Packages.qt6ct
    libsForQt5.qt5ct
    rofi
    scrcpy
    openconnect
    syncthing
    udiskie
    veracrypt
    vlc
    vorta
    wezterm
    zed-editor

    aspell
    aspellDicts.de
    aspellDicts.en
    bat
    btop
    eza
    fd
    fuzzel
    github-cli
    inetutils
    iperf3
    jdk
    khal
    less
    lsof
    p7zip
    pandoc
    ripgrep
    rsync
    sshfs
    tealdeer
    udisks2
    uv
    wget
    which
    unzip
    zip
    xwayland-satellite
    yt-dlp
    zoxide

    fira-code
    noto-fonts-color-emoji
  ];

  fonts.fontconfig.enable = true;

  home.sessionVariables.QT_QPA_PLATFORMTHEME = "qt6ct";
  home.sessionVariables.SAL_USE_VCLPLUGIN = "gtk3";

  home.file = {
    ".bash_profile".source = ./mango/home/.bash_profile;
    ".bashrc".source = ./mango/home/.bashrc;
    ".gitconfig".source = ./mango/home/.gitconfig;
    ".gitignore".source = ./mango/home/.gitignore;
    ".local/share/icons".source = ./mango/icons/.local/share/icons;
  } // lib.mapAttrs'
    (name: _: {
      name = ".local/share/scripts/${name}";
      value = {
        source = scriptDir + "/${name}";
        executable = lib.hasSuffix ".sh" name;
      };
    })
    userScripts;

  xdg.configFile = {
    "doublecmd/doublecmd.xml".source =
      ./mango/doublecmd/.config/doublecmd/doublecmd.xml;
    "gtk-3.0/gtk.css".source = ./mango/gtk-3.0/.config/gtk-3.0/gtk.css;
    "gtk-3.0/settings.ini".source = ./mango/gtk-3.0/.config/gtk-3.0/settings.ini;
    "gtk-4.0/gtk.css" = {
      source = ./mango/gtk-4.0/.config/gtk-4.0/gtk.css;
      force = true;
    };
    "gtk-4.0/settings.ini".source = ./mango/gtk-4.0/.config/gtk-4.0/settings.ini;
    "kitty/kitty.conf".source = ./mango/kitty/.config/kitty/kitty.conf;
    "kitty/dank-tabs.conf".source = ./mango/kitty/.config/kitty/dank-tabs.conf;
    "kitty/dank-theme.conf".source = ./mango/kitty/.config/kitty/dank-theme.conf;
    "mc/ini".source = ./mango/mc/.config/mc/ini;
    "mc/panels.ini".source = ./mango/mc/.config/mc/panels.ini;
    "qt5ct/qt5ct.conf".source = ./mango/qt5ct/.config/qt5ct/qt5ct.conf;
    "qt6ct/qt6ct.conf".source = ./mango/qt6ct/.config/qt6ct/qt6ct.conf;
    "starship.toml".source = ./mango/config/.config/starship.toml;
    "user-dirs.locale".source = ./mango/config/.config/user-dirs.locale;
    "xdg-desktop-portal/mango-portals.conf".source =
      ./mango/config/.config/xdg-desktop-portal/mango-portals.conf;
  };

  xdg.userDirs = {
    desktop = "${config.home.homeDirectory}/Desktop";
    download = "${config.home.homeDirectory}/Downloads";
    templates = "${config.home.homeDirectory}/Templates";
    publicShare = "${config.home.homeDirectory}/Public";
    documents = "${config.home.homeDirectory}/Documents";
    music = "${config.home.homeDirectory}/Music";
    pictures = "${config.home.homeDirectory}/Pictures";
    videos = "${config.home.homeDirectory}/Videos";
    extraConfig.XDG_PROJECTS_DIR = "$HOME/Projects";
  };

  home.activation.createProjectsDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "$HOME/Projects"
  '';
}
