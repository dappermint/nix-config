{ inputs, ... }:

let
  keys = import ../lib/keys.nix;
  user = "dappy";
in
{
  imports = [
    ../modules/system.nix
    ../modules/packages.nix
    ../modules/homebrew.nix
    ../modules/defaults.nix
    ../modules/nix-cache-push.nix
    ../modules/maintenance.nix
    ../modules/github-runners.nix
    ../modules/sbx-backup-pull.nix
    inputs.nix-index-database.darwinModules.nix-index
    inputs.sops-nix.darwinModules.sops
    ../modules/gdrive-mount.nix
    ../modules/secrets.nix
    ../modules/kanata.nix
    ../modules/pixeldish.nix
    inputs.home-manager.darwinModules.home-manager
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  # short magicdns names only, the tailnet id stays out of this public repo
  programs.ssh.knownHosts = {
    dappy-ca = {
      certAuthority = true;
      hostNames = [ "gotham" ];
      publicKey = keys.ca;
    };
    # soft-serve has its own ssh server and can't present a host cert
    gotham-soft-serve = {
      hostNames = [ "[gotham]:23231" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFhHYJnq4JNNXePhPiw5cJCDqxwQH0e2knk65wjlob6Q";
    };
  };

  networking.hostName = "apollo";
  networking.computerName = "apollo";
  networking.localHostName = "apollo";

  system.stateVersion = 7;
  system.primaryUser = user;
  users.users.${user}.home = "/Users/${user}";

  services.nix-cache-push = {
    enable = true;
    safeSSIDs = [
      "petah tikva"
      "sbox_inet"
      "nibbler"
      "6ix7even"
    ];
  };

  services.kanata.enable = true;
  services.gdrive-mount.enable = true;
  services.gh-runners.enable = true;
  services.maintenance.enable = true;
  services.sbx-backup-pull.enable = true;

  launchd.daemons.dev-volume-unlock = {
    script = ''
      target=$(/usr/sbin/diskutil info "onyx" 2>/dev/null | awk -F': *' '/Volume UUID:/{print $2}')
      if [ -n "$target" ]; then
        pass=$(/usr/bin/security find-generic-password -s onyx -w 2>/dev/null || true)
        if [ -n "$pass" ]; then
          echo "$pass" | /usr/sbin/diskutil apfs unlockVolume "$target" -stdinpassphrase || true
        fi
      fi
    '';
    serviceConfig.RunAtLoad = true;
  };

  launchd.user.agents.hermes-webui.serviceConfig =
    let
      h = "/Users/${user}/.hermes";
      python = "${h}/hermes-agent/venv/bin/python";
    in
    {
      Label = "org.${user}.hermes-webui";
      ProgramArguments = [
        python
        "${h}/hermes-webui/bootstrap.py"
        "--foreground"
        "--no-browser"
      ];
      WorkingDirectory = "${h}/hermes-webui";
      EnvironmentVariables = {
        HERMES_WEBUI_PYTHON = python;
        PATH = "${h}/node/bin:${h}/node:${h}/hermes-agent/venv/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/sbin:/usr/local/bin";
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${h}/logs/webui.log";
      StandardErrorPath = "${h}/logs/webui.log";
    };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    backupFileExtension = "hm-backup";
    users.${user} = import ../home/dappy.nix;
  };
}
