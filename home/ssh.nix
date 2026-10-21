{
  config,
  lib,
  pkgs,
  ...
}:

let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  secretiveSock = "${config.home.homeDirectory}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
in
{
  # secure enclave key held by Secretive, every signature needs touch id
  home.file.".ssh/id_enclave.pub" = lib.mkIf isDarwin {
    text = "${(import ../lib/keys.nix).enclave} dappy\n";
  };

  # git and jj sign through ssh-keygen -Y, which only reads SSH_AUTH_SOCK
  home.sessionVariables = lib.mkIf isDarwin { SSH_AUTH_SOCK = secretiveSock; };

  # same for gui apps (zed, lazygit from the dock), which never see shell env
  launchd.agents.secretive-ssh-auth-sock = lib.mkIf isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "/bin/launchctl"
        "setenv"
        "SSH_AUTH_SOCK"
        secretiveSock
      ];
      RunAtLoad = true;
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "yes";
        Compression = false;
        HashKnownHosts = true;
        IdentitiesOnly = true;
        # the clownupdate sessions sit silent for minutes while apt runs, and
        # a nat idle timeout mid-upgrade leaves the remote half-applied
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        # reuse the first connection to a host for every later one (lazygit,
        # scp, a second tmux), so only one handshake is paid per host. the
        # master lingers ten minutes after the last client closes
        ControlMaster = "auto";
        ControlPersist = "10m";
        ControlPath = "~/.ssh/cm-%r@%h:%p";
      }
      // lib.optionalAttrs isDarwin { IdentityAgent = secretiveSock; };

      # the enclave key wants touch id per connection, so only offer it when a
      # human is at a terminal. ssh points match-exec stdin at /dev/null, hence
      # fd 2. ansible forks, agents and nix copy stay on the file ed25519
      # instead of queueing dozens of prompts
      enclave-interactive = lib.mkIf isDarwin (
        lib.hm.dag.entryBefore [ "ed25519" ] {
          header = ''Match host "*,!railway.new" exec "test -t 2"'';
          IdentityFile = "~/.ssh/id_enclave.pub";
        }
      );

      # also backs sops, so it never goes away
      ed25519 = lib.mkIf isDarwin {
        header = "Host * !railway.new";
        IdentityFile = "~/.ssh/id_ed25519";
      };

      # throwaway identity for public/anonymous services, never the main key
      "railway.new" = {
        IdentityFile = "~/.ssh/id_ed25519_public";
        IdentitiesOnly = true;
      };

      "ipad 10.25.60.16" = {
        HostName = "10.25.60.16";
        User = "root";
        HostKeyAlgorithms = "+ssh-rsa";
        PubkeyAcceptedKeyTypes = "+ssh-rsa";
      };
    };
  };
}
