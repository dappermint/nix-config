{ config, ... }:

{
  # ssh targets come from the sops-rendered secrets.fish, so the justfile never
  # names a host. the :? expansions make a missing value a hard failure instead
  # of an ssh to nowhere
  home.file."justfile".text = ''
    default:
        @just --list

    # update everything: netbird + gitlab
    clownupdate: clownupdate-netbird clownupdate-gitlab

    # update netbird quadlets on the clownway netbird server to latest stable
    clownupdate-netbird:
        #!/usr/bin/env bash
        set -euo pipefail
        host=''${CLOWNWAY_NETBIRD_HOST:?not set - is the sops secrets.fish sourced?}
        nb=$(curl -sf https://api.github.com/repos/netbirdio/netbird/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
        dash=$(curl -sf https://api.github.com/repos/netbirdio/dashboard/releases/latest | grep '"tag_name"' | sed 's/.*"\(v[^"]*\)".*/\1/')
        echo "netbird -> v''${nb}, dashboard -> ''${dash}"
        ssh "''${host}" bash << ENDSSH
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
        host=''${CLOWNWAY_GITLAB_HOST:?not set - is the sops secrets.fish sourced?}
        ssh "''${host}" bash << ENDSSH
        set -euo pipefail
        sudo apt-get update -q
        sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
        ENDSSH
  '';

  programs.fish.functions.clownupdate = ''
    just --justfile ${config.home.homeDirectory}/justfile clownupdate $argv
  '';
}
