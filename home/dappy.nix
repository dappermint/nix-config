{ pkgs, lib, ... }:

{
  home.stateVersion = "25.05";

  home.username = lib.mkForce "dappy";
  home.homeDirectory = lib.mkForce "/Users/dappy";

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "*" = {
        forwardAgent = false;
        addKeysToAgent = "yes";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };

      "nix-builder-arm nix-builder-arm.clownway.org" = {
        hostname = "nix-builder-arm.clownway.org";
        user = "builder";
        identityFile = "~/.ssh/nix_builder";
        identitiesOnly = true;
        extraOptions = {
          StrictHostKeyChecking = "accept-new";
        };
      };

      "nix-builder-x86 nix-builder-x86.clownway.org" = {
        hostname = "nix-builder-x86.clownway.org";
        user = "builder";
        identityFile = "~/.ssh/nix_builder";
        identitiesOnly = true;
        extraOptions = {
          StrictHostKeyChecking = "accept-new";
        };
      };
    };
  };

  programs.fish = {
    enable = true;

    functions = {
      nix-builder-up = ''
        set -l names nix-builder-arm nix-builder-x86
        if test (count $argv) -gt 0
          set names $argv
        end
        set -l ids
        for name in $names
          set -l id (aws --profile fyffe --region eu-north-1 ec2 describe-instances \
            --filters "Name=tag:Name,Values=$name" "Name=instance-state-name,Values=stopped,stopping,pending,running" \
            --query 'Reservations[0].Instances[0].InstanceId' --output text)
          if test -z "$id" -o "$id" = None
            echo "$name: no instance found" >&2
            continue
          end
          echo "starting $name ($id)..."
          aws --profile fyffe --region eu-north-1 ec2 start-instances --instance-ids $id >/dev/null
          set ids $ids $id
        end
        if test (count $ids) -gt 0
          aws --profile fyffe --region eu-north-1 ec2 wait instance-running --instance-ids $ids
          echo "waiting for ssh..."
          for name in $names
            while not ssh -o ConnectTimeout=3 -o BatchMode=yes $name true 2>/dev/null
              sleep 5
            end
            echo "$name ready"
          end
        end
      '';

      nix-builder-down = ''
        set -l names nix-builder-arm nix-builder-x86
        if test (count $argv) -gt 0
          set names $argv
        end
        for name in $names
          set -l id (aws --profile fyffe --region eu-north-1 ec2 describe-instances \
            --filters "Name=tag:Name,Values=$name" "Name=instance-state-name,Values=running,pending" \
            --query 'Reservations[0].Instances[0].InstanceId' --output text)
          if test -n "$id" -a "$id" != None
            echo "stopping $name ($id)..."
            aws --profile fyffe --region eu-north-1 ec2 stop-instances --instance-ids $id >/dev/null
          end
        end
      '';

      nix-builder-status = ''
        for name in nix-builder-arm nix-builder-x86
          set -l state (aws --profile fyffe --region eu-north-1 ec2 describe-instances \
            --filters "Name=tag:Name,Values=$name" \
            --query 'Reservations[0].Instances[0].[InstanceId,State.Name,PrivateIpAddress]' --output text)
          echo "$name: $state"
        end
      '';

      nix-cache-creds-install = ''
        set -l tofu_dir "$HOME/Documents/Werk/repos/conway/infra/tofu/environments/infra"
        set -l reader_id (tofu -chdir=$tofu_dir output -raw nix_cache_reader_access_key_id)
        set -l reader_secret (tofu -chdir=$tofu_dir output -raw nix_cache_reader_secret_access_key)
        set -l writer_id (tofu -chdir=$tofu_dir output -raw nix_cache_writer_access_key_id)
        set -l writer_secret (tofu -chdir=$tofu_dir output -raw nix_cache_writer_secret_access_key)

        if test -z "$reader_id" -o -z "$reader_secret" -o -z "$writer_id" -o -z "$writer_secret"
          echo "tofu outputs missing - did you tofu apply?" >&2
          return 1
        end

        set -l creds "$HOME/.aws/credentials"
        mkdir -p (dirname $creds)
        touch $creds

        for profile in nix-cache nix-cache-writer
          if grep -q "^\[$profile\]" $creds
            echo "[$profile] profile already exists in $creds; remove it manually first" >&2
            return 1
          end
        end

        printf '\n[nix-cache]\naws_access_key_id = %s\naws_secret_access_key = %s\nregion = eu-north-1\n' \
          $reader_id $reader_secret >> $creds
        printf '\n[nix-cache-writer]\naws_access_key_id = %s\naws_secret_access_key = %s\nregion = eu-north-1\n' \
          $writer_id $writer_secret >> $creds
        chmod 0600 $creds
        echo "wrote [nix-cache] and [nix-cache-writer] profiles to $creds"
      '';

      nix-cache-key-install = ''
        set -l src "$HOME/Documents/Werk/repos/conway/infra/tofu/environments/infra/secrets/nix-cache-priv.pem"
        set -l dst /var/root/nix-cache-priv.pem
        if not test -f $src
          echo "signing key not found at $src" >&2
          return 1
        end
        sudo install -o root -g wheel -m 0400 $src $dst
        echo "installed signing key to $dst"
      '';
    };
  };
}
