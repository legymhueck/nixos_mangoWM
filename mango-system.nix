{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    acpi
    alsa-firmware
    alsa-oss
    alsa-utils
    asciidoc
    asciidoctor
    bash-completion
    bind
    bluez
    bolt
    brightnessctl
    btrfs-progs
    compsize
    cups
    cups-pk-helper
    ddcutil
    dosfstools
    exfatprogs
    fail2ban
    fprintd
    fwupd
    i2c-tools
    inetutils
    intel-gpu-tools
    intel-media-driver
    jq
    man-db
    man-pages
    mesa
    nfs-utils
    nftables
    ntfs3g
    openssh
    rtkit
    smartmontools
    sof-firmware
    strace
    tpm2-tools
    traceroute
    usbutils
    vulkan-tools
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
    xdg-utils
    xwayland
  ];

  services.printing.enable = true;
  services.fprintd.enable = true;
  services.fwupd.enable = true;
  services.tailscale.enable = true;

  hardware.firmware = [ pkgs.sof-firmware ];

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
    ];
  };
}
