{ pkgs, inputs, ... }:

{
  environment.systemPackages = (with pkgs; [
    fastfetch
    micro
    fd
    hyfetch
    ansible
    ansible-lint
    awscli2
    bat
    bottom
    bun
    eksctl
    elvish
    eza
    git-filter-repo
    gh
    go
    just
    k9s
    kubectl
    kubernetes-helm
    lazygit
    neovim
    nodejs
    opentofu
    pre-commit
    python3Packages.fonttools
    ripgrep
    ookla-speedtest
    sshpass
    upcloud-cli
    uv
    vault
    woff2
    yamllint
  ]) ++ [
    inputs.clownctl.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
