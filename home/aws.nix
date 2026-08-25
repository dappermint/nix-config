{ config, pkgs, ... }:

let
  repo = import ../lib/repo.nix;

  profile = "fyffe";
  region = "eu-north-1";
  cluster = "infra";

  awsConfig = "${config.home.homeDirectory}/.aws/config";

  # tofu output names and sops keys are deliberately identical, so the import
  # below is a straight copy
  cacheCredentialKeys = [
    "nix_cache_reader_access_key_id"
    "nix_cache_reader_secret_access_key"
    "nix_cache_writer_access_key_id"
    "nix_cache_writer_secret_access_key"
  ];

  credsFilter = builtins.concatStringsSep ", " (map (k: "${k}: .${k}.value") cacheCredentialKeys);

  credsMerge = pkgs.writeShellApplication {
    name = "nix-cache-creds-merge";
    runtimeInputs = [ pkgs.yq-go ];
    text = ''
      yq -i '. * (strenv(TOFU_CREDS) | fromjson)' "$1"
    '';
  };

  # tofu owns the s3 cache keys, sops stores them, nix renders
  # ~/.aws/credentials. the values ride in through the environment and sops'
  # editor tempfile, never argv, so they never show up in ps
  credsImport = pkgs.writeShellApplication {
    name = "nix-cache-creds-import";
    runtimeInputs = [
      credsMerge
      pkgs.jq
      pkgs.opentofu
      pkgs.sops
    ];
    text = ''
      tofu_dir="$HOME/Documents/Werk/repos/conway/infra/tofu/environments/infra"

      if [ ! -d "$tofu_dir" ]; then
        echo "tofu directory missing: $tofu_dir" >&2
        exit 1
      fi

      creds=$(tofu -chdir="$tofu_dir" output -json | jq '{ ${credsFilter} }')

      for key in ${builtins.concatStringsSep " " cacheCredentialKeys}; do
        if [ -z "$(jq -r --arg k "$key" '.[$k] // empty' <<<"$creds")" ]; then
          echo "tofu output $key is empty - did you tofu apply?" >&2
          exit 1
        fi
      done

      export SOPS_AGE_KEY_FILE="''${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

      sops_status=0
      TOFU_CREDS=$creds EDITOR=nix-cache-creds-merge sops edit ${repo.secretsFile} \
        || sops_status=$?
      # 200 is sops for "the file did not change"
      if [ "$sops_status" -ne 0 ] && [ "$sops_status" -ne 200 ]; then
        exit "$sops_status"
      fi

      echo "imported ${toString (builtins.length cacheCredentialKeys)} keys into ${repo.secretsFile}"
      echo "run nix-update to re-render ~/.aws/credentials"
    '';
  };
in
{
  home.packages = [ credsImport ];

  programs.fish.functions = {
    eks-login = ''
      if not test -r ${awsConfig}
        echo "${awsConfig} is missing; sops has not rendered it yet" >&2
        return 1
      end

      set -gx AWS_PROFILE ${profile}
      set -gx AWS_REGION ${region}
      set -gx AWS_DEFAULT_REGION ${region}

      echo "==> sso login (${profile})"
      aws sso login --profile ${profile}
      or begin
        echo "sso login failed" >&2
        return 1
      end

      aws sts get-caller-identity --profile ${profile}
      or begin
        echo "aws auth failed" >&2
        return 1
      end

      echo "==> updating kubeconfig for '${cluster}'"
      aws eks update-kubeconfig --name ${cluster} --region ${region} --profile ${profile} --alias ${cluster}
      or begin
        echo "failed to update kubeconfig" >&2
        return 1
      end

      kubectl cluster-info
    '';
  };
}
