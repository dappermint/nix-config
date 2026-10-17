{ lib, pkgs, ... }:

let
  identity = {
    name = "millia ampora";
    email = "198710911+dappermint@users.noreply.github.com";
  };
  # secure enclave key on apollo (see ssh.nix), the sops ed25519 elsewhere
  signingKey =
    if pkgs.stdenv.hostPlatform.isDarwin then "~/.ssh/id_enclave.pub" else "~/.ssh/id_ed25519.pub";

  # nix-darwin keeps the system profile on a stable path. rubicon is a standalone
  # home-manager host with no /run/current-system, so resolve gh out of the
  # package set there instead
  ghBin =
    if pkgs.stdenv.hostPlatform.isDarwin then "/run/current-system/sw/bin/gh" else lib.getExe pkgs.gh;
in
{
  # the ed25519 stays listed so commits signed before the enclave key still verify
  home.file.".ssh/allowed_signers".text = ''
    ${identity.email} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN7KvZLKybxYKt5Vu5UPcQ4zxIq+FPRyAKQgnvOpzy6Z
    ${identity.email} ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBPltwbYS6FRFdE7ZGAdOfewqsvHLX1H9jQEXt+/tXoc1JzE/pAwZUldTzhaoZ9alMAaV+cXIFZyAT3Bn87gEgeE=
  '';

  programs.jujutsu = {
    enable = true;
    settings = {
      user = identity;
      signing = {
        behavior = "own";
        backend = "ssh";
        key = signingKey;
      };
    };
  };

  # difftool wired by hand: home-manager refuses difftastic.git.enable beside
  # delta.enableGitIntegration. delta keeps `git diff`, difft answers `git difftool`
  programs.difftastic.enable = true;

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = identity.name;
      user.email = identity.email;
      user.signingkey = signingKey;
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      commit.gpgsign = true;
      tag.gpgsign = true;
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
      diff.tool = "difftastic";
      difftool.prompt = false;
      difftool.difftastic.cmd = ''difft "$LOCAL" "$REMOTE"'';
      diff.mnemonicPrefix = true;
      diff.renames = true;
      column.ui = "auto";
      branch.sort = "-committerdate";
      tag.sort = "version:refname";
      help.autocorrect = "prompt";
      commit.verbose = true;
      log.date = "iso";
      core.untrackedCache = true;
      credential."https://github.com".helper = "!${ghBin} auth git-credential";
      credential."https://gist.github.com".helper = "!${ghBin} auth git-credential";
    };
  };
}
