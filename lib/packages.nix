# package groups shared between hosts. apollo takes all of them; rubicon, the
# android linux terminal, takes the portable subset, so the phone gets the same
# tools under the same names without a second list to keep in sync.
#
# anything that only makes sense on one platform stays out of here: macmon,
# ratatouille, tart and hey-cli are darwin-only and live in modules/packages.nix
{ pkgs }:

{
  shell = with pkgs; [
    bat
    bottom
    # phone to laptop by pairing code, no shared network or open port needed
    croc
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
    # ssh that survives the phone changing networks or sleeping. the package
    # carries mosh-server too, so apollo is a target by taking the group
    mosh
    ookla-speedtest
    ouch
    pik
    ripgrep
    rsync
    sd
    tealdeer
    trippy
    xh
    yq-go
    rclone
  ];

  vcs = with pkgs; [
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
    cloudflared
    freerdp
    opentofu
    sops
    sshpass
    step-ca
    step-cli
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

  browsers = with pkgs; [
    obscura
  ];
}
