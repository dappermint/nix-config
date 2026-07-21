{
  self,
  config,
  primaryUsername,
  primaryHomeDirectory,
  ...
}:

{
  sops = {
    defaultSopsFile = "${self}/secrets/secrets.yaml";
    age.sshKeyPaths = [ "${primaryHomeDirectory}/.ssh/id_ed25519" ];

    secrets.upcloud_token = { };

    secrets."nix-cache-priv-key" = {
      key = "nix_cache_priv_key";
      owner = "root";
      mode = "0400";
    };

    secrets.conway_kubeconfig = {
      owner = primaryUsername;
      mode = "0400";
      path = "${primaryHomeDirectory}/.kube/conway";
    };

    templates."secrets.fish" = {
      owner = primaryUsername;
      mode = "0400";
      content = ''
        set -x UPCLOUD_TOKEN ${config.sops.placeholder.upcloud_token}
      '';
    };
  };

  programs.fish.shellInit = ''
    test -r "${config.sops.templates."secrets.fish".path}"; and source "${
      config.sops.templates."secrets.fish".path
    }"
  '';
}
