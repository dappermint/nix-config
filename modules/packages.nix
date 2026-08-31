{ pkgs, inputs, ... }:

let
  shell = with pkgs; [
    bat
    bottom
    doggo
    dust
    elvish
    entr
    eza
    (fastfetch.override { runtimeDependencies = [ ]; })
    fd
    glow
    hyfetch
    hyperfine
    jq
    just
    lnav
    micro
    ookla-speedtest
    ouch
    pik
    ripgrep
    sd
    tealdeer
    television
    trippy
    xh
    yq-go
  ];

  vcs = with pkgs; [
    gh
    git-filter-repo
    glab
    jjui
    lazygit
    pre-commit
    serie
    zizmor
  ];

  editors = [ pkgs.neovim ];

  agents = with pkgs; [
    codex
    grok
  ];

  languages = with pkgs; [
    bun
    go
    nodejs
  ];

  # awscli2 crashes through libffi on macOS 27, so homebrew owns it for now
  infra = with pkgs; [
    ansible
    ansible-lint
    freerdp
    opentofu
    sops
    sshpass
    upcloud-cli
    vault
    yamllint
  ];

  kubernetes = with pkgs; [
    argocd
    eksctl
    k9s
    kubectl
    kubernetes-helm
  ];

  nixTooling = with pkgs; [
    nix-output-monitor
    nixd
  ];

  fontTooling = with pkgs; [
    cabextract
    python3Packages.fonttools
    woff2
  ];

  macos = [
    pkgs.macmon
    inputs.ratatouille.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  toys = [ inputs.tart.packages.${pkgs.stdenv.hostPlatform.system}.default ];
in
{
  environment.systemPackages =
    shell
    ++ vcs
    ++ editors
    ++ agents
    ++ languages
    ++ infra
    ++ kubernetes
    ++ nixTooling
    ++ fontTooling
    ++ macos
    ++ toys;
}
