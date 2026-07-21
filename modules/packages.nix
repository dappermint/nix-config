{ pkgs, ... }:

{
  # awscli2 crashes through libffi on macOS 27, so homebrew owns it for now
  environment.systemPackages = with pkgs; [
    ansible
    ansible-lint
    bat
    bottom
    bun
    codex
    dust
    eksctl
    elvish
    eza
    fastfetch
    fd
    gh
    git-filter-repo
    go
    hyfetch
    just
    kubectl
    kubernetes-helm
    lazygit
    micro
    neovim
    nh
    nodejs
    ookla-speedtest
    opentofu
    pre-commit
    python3Packages.fonttools
    ripgrep
    sshpass
    upcloud-cli
    uv
    vault
    woff2
    yamllint
  ];
}
