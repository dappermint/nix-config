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
    ripgrep
    sd
    tealdeer
    trippy
    xh
    yq-go
  ];

  vcs = with pkgs; [
    difftastic
    gh
    git-filter-repo
    glab
    lazygit
    pre-commit
    serie
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
    uv
  ];

  # awscli2 crashes through libffi on macOS 27, so homebrew owns it for now
  infra = with pkgs; [
    ansible
    ansible-lint
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

  nixTooling = [ pkgs.nix-output-monitor ];

  fontTooling = with pkgs; [
    cabextract
    python3Packages.fonttools
    woff2
  ];

  macos = [
    pkgs.macmon
    inputs.ratatouille.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
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
    ++ macos;
}
