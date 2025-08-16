{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Bootloader (Lanzaboote replaces systemd-boot in flake)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Los_Angeles";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
  };

  # Keep GNOME available as fallback; GDM for login (Wayland on)
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  services.desktopManager.gnome.enable = true;

  # Keyboard
  services.xserver.xkb = { layout = "us"; variant = ""; };

  # Printing
  services.printing.enable = true;

  # PipeWire (audio)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;  # provides PulseAudio API for Waybar module
  };

  # User
  users.users.pierce = {
    isNormalUser = true;
    description = "Pierce Governale";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ ];
  };

  programs.firefox.enable = true;

  # Unfree allowed
  nixpkgs.config.allowUnfree = true;

  # NVIDIA + Wayland env
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [ nvidia-vaapi-driver ];
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  # Hyprland (session is wired in flake; keep here to expose options)
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # Polkit (system service) — the agent runs in Home Manager
  security.polkit.enable = true;

  # Portals (use Hyprland portal + GTK as fallback)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = { common = { default = [ "hyprland" "gtk" ]; }; };
  };

  # GNOME Keyring for secrets
  services.gnome.gnome-keyring.enable = true;

  # PAM entry for hyprlock (required for unlocking)
  security.pam.services.hyprlock = {};

  # System fonts
  fonts.packages = with pkgs; [
    noto-fonts noto-fonts-cjk-sans noto-fonts-emoji
    nerd-fonts.jetbrains-mono nerd-fonts.fira-code
  ];

  # Games (optional; keep your originals)
  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.gamescope.enable = true;
  programs.gamemode.enable = true;

  # Flatpak
  services.flatpak.enable = true;

  # Packages (add what you had)
  environment.systemPackages = with pkgs; [
    mangohud protonup-qt lutris bottles heroic vscode discord
    code-cursor warp-terminal gh git nodejs_24 pnpm claude-code
    manuskript python312 sbctl kitty xfce.thunar
  ];

  # Wayland/NVIDIA-friendly env
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_RENDERER = "vulkan";
    # If the Hyprland env above fixes artifacts, you can keep this commented here:
    # WLR_NO_HARDWARE_CURSORS = "1";
  };

  # State version
  system.stateVersion = "25.05";
}
