{ config, ... }:

let
  repo = import ../lib/repo.nix;

  profile = "fyffe";
  region = "eu-north-1";
  cluster = "infra";

  awsConfig = "${config.home.homeDirectory}/.aws/config";

  # tofu output names and sops keys are deliberately identical, so the import
  # loop below is a straight copy
  cacheCredentialKeys = [
    "nix_cache_reader_access_key_id"
    "nix_cache_reader_secret_access_key"
    "nix_cache_writer_access_key_id"
    "nix_cache_writer_secret_access_key"
  ];
in
{
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

    # tofu owns the s3 cache keys, sops stores them, nix renders
    # ~/.aws/credentials. this only moves them from the first to the second
    nix-cache-creds-import = ''
      set -l tofu_dir "$HOME/Documents/Werk/repos/conway/infra/tofu/environments/infra"

      if not test -d $tofu_dir
        echo "tofu directory missing: $tofu_dir" >&2
        return 1
      end

      for key in ${builtins.concatStringsSep " " cacheCredentialKeys}
        set -l value (tofu -chdir=$tofu_dir output -raw $key)
        if test -z "$value"
          echo "tofu output $key is empty - did you tofu apply?" >&2
          return 1
        end
        sops set ${repo.secretsFile} "[\"$key\"]" (printf '%s' $value \
          | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
      end

      echo "imported ${toString (builtins.length cacheCredentialKeys)} keys into ${repo.secretsFile}"
      echo "run nix-update to re-render ~/.aws/credentials"
    '';
  };
}
