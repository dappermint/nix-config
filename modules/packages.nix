{ pkgs, inputs, ... }:

let
  shell = with pkgs; [
    bat
    bottom
    dust
    elvish
    entr
    eza
    fastfetch
    fd
    hyfetch
    hyperfine
    jq
    just
    micro
    ookla-speedtest
    ripgrep
    tealdeer
    yq-go
  ];

  vcs = with pkgs; [
    gh
    git-filter-repo
    lazygit
    pre-commit
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
    eksctl
    k9s
    kubectl
    kubernetes-helm
  ];

  nixTooling = with pkgs; [
    nh
    nix-output-monitor
  ];

  fontTooling = with pkgs; [
    cabextract
    python3Packages.fonttools
    woff2
  ];

  macos = [ inputs.mac-cleaner.packages.${pkgs.stdenv.hostPlatform.system}.default ];
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
