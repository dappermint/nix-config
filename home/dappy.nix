{
  lib,
  primaryHomeDirectory,
  ...
}:

let
  awsProfile = "fyffe";
  awsRegion = "eu-north-1";
  monoFontFamily = "GeistMono Nerd Font Mono";
  monoFontPostScriptName = "GeistMonoNFM-Regular";
  nixDarwinDirectory = "/etc/nix-darwin";
  nixpkgsBranch = "nixpkgs-unstable";
  nixpkgsMirror = "$HOME/Code/nixpkgs";
in
{
  imports = [ ./obs.nix ];

  home = {
    stateVersion = "25.05";
    enableNixpkgsReleaseCheck = false;
  };

  # merge the conway k8s cluster (sops-managed at ~/.kube/conway) with existing contexts
  home.sessionVariables.KUBECONFIG = "${primaryHomeDirectory}/.kube/config:${primaryHomeDirectory}/.kube/conway";

  home.file.".config/fastfetch/config.jsonc".text = builtins.toJSON {
    "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json";
    modules = [
      "title"
      "separator"
      "os"
      "host"
      "kernel"
      "uptime"
      "packages"
      "shell"
      "terminal"
      {
        type = "command";
        key = "Nix";
        text = ''echo "Lix $(/run/current-system/sw/bin/nix --version | head -1 | awk '{print $NF}')"'';
      }
      "cpu"
      "gpu"
      "memory"
      "disk"
      "battery"
      "datetime"
      "break"
      "colors"
    ];
  };

  home.file."justfile".text = ''
    default:
        @just --list

    # update everything: netbird + gitlab
    clownupdate: clownupdate-netbird clownupdate-gitlab

    # update netbird quadlets on the clownway netbird server to latest stable
    clownupdate-netbird:
        #!/usr/bin/env bash
        set -euo pipefail
        nb=$(curl -sf https://api.github.com/repos/netbirdio/netbird/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
        dash=$(curl -sf https://api.github.com/repos/netbirdio/dashboard/releases/latest | grep '"tag_name"' | sed 's/.*"\(v[^"]*\)".*/\1/')
        echo "netbird -> v''${nb}, dashboard -> ''${dash}"
        ssh ubuntu@16.171.108.167 bash << ENDSSH
        set -euo pipefail
        sudo sed -i "s|netbirdio/management:.*|netbirdio/management:''${nb}|" /etc/containers/systemd/netbird-management.container
        sudo sed -i "s|netbirdio/relay:.*|netbirdio/relay:''${nb}|" /etc/containers/systemd/netbird-relay.container
        sudo sed -i "s|netbirdio/signal:.*|netbirdio/signal:''${nb}|" /etc/containers/systemd/netbird-signal.container
        sudo sed -i "s|netbirdio/dashboard:.*|netbirdio/dashboard:''${dash}|" /etc/containers/systemd/netbird-dashboard.container
        sudo systemctl daemon-reload
        sudo systemctl restart netbird-management netbird-relay netbird-signal netbird-dashboard
        systemctl is-active netbird-management netbird-relay netbird-signal netbird-dashboard
        ENDSSH

    # apt update + upgrade on the clownway gitlab server
    clownupdate-gitlab:
        #!/usr/bin/env bash
        set -euo pipefail
        ssh ubuntu@10.0.7.178 bash << ENDSSH
        set -euo pipefail
        sudo apt-get update -q
        sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
        ENDSSH
  '';

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    flags = [ "--disable-up-arrow" ];
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.zed-editor = {
    enable = true;
    package = null;
    userSettings = {
      ui_font_family = "Geist";
      buffer_font_family = monoFontFamily;
      terminal.font_family = monoFontFamily;
    };
  };

  home.activation.fontDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /usr/bin/defaults write NSGlobalDomain NSFixedPitchFont -string "${monoFontPostScriptName}"
    run /usr/bin/defaults write dev.warp.Warp-Preview FontName -string '"${monoFontFamily}"'
  '';

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "yes";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "Liah Yoffe";
      user.email = "liahyoffe@gmail.com";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      push.default = "simple";
      push.followTags = true;
      pull.rebase = false;
      fetch.prune = true;
      fetch.pruneTags = true;
      fetch.parallel = 0;
      rebase.autoStash = true;
      rebase.autoSquash = true;
      rebase.updateRefs = true;
      merge.conflictStyle = "zdiff3";
      rerere.enabled = true;
      rerere.autoUpdate = true;
      diff.algorithm = "histogram";
      diff.colorMoved = "default";
      diff.mnemonicPrefix = true;
      diff.renames = true;
      column.ui = "auto";
      branch.sort = "-committerdate";
      tag.sort = "version:refname";
      help.autocorrect = "prompt";
      commit.verbose = true;
      log.date = "iso";
      core.untrackedCache = true;
      credential."https://github.com".helper = "!/run/current-system/sw/bin/gh auth git-credential";
      credential."https://gist.github.com".helper = "!/run/current-system/sw/bin/gh auth git-credential";
    };
  };

  programs.fish = {
    enable = true;

    shellAbbrs = {
      nixb = "nom build";
      nixd = "nom develop";
      nixs = "nom shell";
    };

    functions = {
      clownupdate = ''
        just --justfile $HOME/justfile clownupdate $argv
      '';

      eks-login = ''
        set -l profile ${awsProfile}
        set -l region ${awsRegion}
        set -l cluster infra
        set -l sso_start_url https://ssoins-6508d9799401466e.portal.eu-north-1.app.aws
        set -l sso_account_id 490224159551
        set -l sso_role AdministratorAccess

        echo "==> configuring sso profile '$profile' (account $sso_account_id, cluster $cluster)"
        aws configure set sso_start_url $sso_start_url --profile $profile
        aws configure set sso_region $region --profile $profile
        aws configure set sso_account_id $sso_account_id --profile $profile
        aws configure set sso_role_name $sso_role --profile $profile
        aws configure set region $region --profile $profile
        aws configure set output json --profile $profile

        set -gx AWS_PROFILE $profile
        set -gx AWS_REGION $region
        set -gx AWS_DEFAULT_REGION $region

        echo "==> sso login"
        aws sso login --profile $profile
        or begin
          echo "sso login failed" >&2
          return 1
        end

        aws sts get-caller-identity --profile $profile
        or begin
          echo "aws auth failed" >&2
          return 1
        end

        echo "==> updating kubeconfig for '$cluster'"
        aws eks update-kubeconfig --name $cluster --region $region --profile $profile --alias $cluster
        or begin
          echo "failed to update kubeconfig" >&2
          return 1
        end

        kubectl cluster-info
      '';

      nix-cache-creds-install = ''
        set -l tofu_dir "$HOME/Documents/Werk/repos/conway/infra/tofu/environments/infra"
        set -l reader_id (tofu -chdir=$tofu_dir output -raw nix_cache_reader_access_key_id)
        set -l reader_secret (tofu -chdir=$tofu_dir output -raw nix_cache_reader_secret_access_key)
        set -l writer_id (tofu -chdir=$tofu_dir output -raw nix_cache_writer_access_key_id)
        set -l writer_secret (tofu -chdir=$tofu_dir output -raw nix_cache_writer_secret_access_key)

        if test -z "$reader_id" -o -z "$reader_secret" -o -z "$writer_id" -o -z "$writer_secret"
          echo "tofu outputs missing - did you tofu apply?" >&2
          return 1
        end

        set -l creds "$HOME/.aws/credentials"
        mkdir -p (dirname $creds)
        touch $creds

        for profile in nix-cache nix-cache-writer
          if grep -q "^\[$profile\]" $creds
            echo "[$profile] profile already exists in $creds; remove it manually first" >&2
            return 1
          end
        end

        printf '\n[nix-cache]\naws_access_key_id = %s\naws_secret_access_key = %s\nregion = eu-north-1\n' \
          $reader_id $reader_secret >> $creds
        printf '\n[nix-cache-writer]\naws_access_key_id = %s\naws_secret_access_key = %s\nregion = eu-north-1\n' \
          $writer_id $writer_secret >> $creds
        chmod 0600 $creds
        echo "wrote [nix-cache] and [nix-cache-writer] profiles to $creds"

        aws configure set s3.max_bandwidth 2MB/s --profile nix-cache-writer
        aws configure set s3.max_concurrent_requests 2 --profile nix-cache-writer
        echo "set s3.max_bandwidth=2MB/s and s3.max_concurrent_requests=2 for nix-cache-writer"
      '';

      nix-mirror-setup = ''
        set -l mirror "${nixpkgsMirror}"
        if test -d $mirror/.git
          echo "mirror already exists at $mirror"
          return 0
        end
        mkdir -p (dirname $mirror)
        echo "cloning nixpkgs (partial, blob:none) into $mirror ..."
        git clone --filter=blob:none --no-checkout \
          --branch ${nixpkgsBranch} \
          https://github.com/NixOS/nixpkgs $mirror
        git -C $mirror update-ref refs/heads/${nixpkgsBranch} origin/${nixpkgsBranch}
        echo "done. local ref refs/heads/${nixpkgsBranch} points at upstream tip"
      '';

      nix-mirror-update = ''
        set -l mirror "${nixpkgsMirror}"
        if not test -d $mirror/.git
          echo "mirror missing; run nix-mirror-setup first" >&2
          return 1
        end
        echo "fetching origin/${nixpkgsBranch} (partial) ..."
        git -C $mirror fetch --filter=blob:none origin ${nixpkgsBranch}
        git -C $mirror update-ref refs/heads/${nixpkgsBranch} origin/${nixpkgsBranch}
        echo "updating flake input nixpkgs ..."
        nix flake update nixpkgs --flake ${nixDarwinDirectory}
      '';

      nix-update = ''
        nh darwin switch --update --diff always ${nixDarwinDirectory}
      '';
    };
  };
}
