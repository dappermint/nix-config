{
  self,
  config,
  lib,
  ...
}:

let
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;

  inherit (config.sops) placeholder;

  userSecret = {
    owner = user;
    mode = "0400";
  };

  awsRegion = "eu-north-1";
in
{
  sops = {
    defaultSopsFile = "${self}/secrets/secrets.yaml";
    age.sshKeyPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
      "${home}/.ssh/id_ed25519"
    ];

    secrets = {
      upcloud_token = { };

      "nix-cache-priv-key" = {
        key = "nix_cache_priv_key";
        owner = "root";
        mode = "0400";
      };

      conway_kubeconfig = userSecret // {
        path = "${home}/.kube/conway";
      };

      youtube_stream_key = userSecret // {
        path = "${home}/.config/obs/youtube-stream-key";
      };

      clownway_netbird_host = { };
      clownway_gitlab_host = { };
      # not exported globally — the conway repos pull these in via direnv
      clownway_gitlab_token = userSecret;
      clownway_netbird_token = userSecret;
      aws_sso_start_url = { };
      aws_sso_account_id = { };

      nix_cache_reader_access_key_id = { };
      nix_cache_reader_secret_access_key = { };
      nix_cache_writer_access_key_id = { };
      nix_cache_writer_secret_access_key = { };
    };

    templates = {
      "secrets.fish" = userSecret // {
        content = ''
          set -gx UPCLOUD_TOKEN '${placeholder.upcloud_token}'
          set -gx CLOWNWAY_NETBIRD_HOST '${placeholder.clownway_netbird_host}'
          set -gx CLOWNWAY_GITLAB_HOST '${placeholder.clownway_gitlab_host}'
        '';
      };

      "aws-credentials" = {
        owner = user;
        mode = "0600";
        path = "${home}/.aws/credentials";
        content = ''
          [nix-cache]
          aws_access_key_id = ${placeholder.nix_cache_reader_access_key_id}
          aws_secret_access_key = ${placeholder.nix_cache_reader_secret_access_key}

          [nix-cache-writer]
          aws_access_key_id = ${placeholder.nix_cache_writer_access_key_id}
          aws_secret_access_key = ${placeholder.nix_cache_writer_secret_access_key}
        '';
      };

      "aws-config" = {
        owner = user;
        mode = "0600";
        path = "${home}/.aws/config";
        content = ''
          [profile fyffe]
          sso_start_url = ${placeholder.aws_sso_start_url}
          sso_region = ${awsRegion}
          sso_account_id = ${placeholder.aws_sso_account_id}
          sso_role_name = AdministratorAccess
          region = ${awsRegion}
          output = json

          [profile nix-cache]
          region = ${awsRegion}

          [profile nix-cache-writer]
          region = ${awsRegion}
          s3 =
              max_bandwidth = 2MB/s
              max_concurrent_requests = 2
        '';
      };
    };
  };

  # a directory sops has to mkdir on the way to a secret ends up root-owned,
  # so hand them to the user first; extraActivation runs before the secrets
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    install -d -o ${user} -g staff ${home}/.aws ${home}/.config ${home}/.config/obs ${home}/.kube
  '';

  programs.fish.shellInit = ''
    test -r "${config.sops.templates."secrets.fish".path}"; and source "${
      config.sops.templates."secrets.fish".path
    }"
  '';
}
