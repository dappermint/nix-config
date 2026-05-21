{ self, config, ... }:

{
  sops = {
    defaultSopsFile = "${self}/secrets/secrets.yaml";
    age.sshKeyPaths = [ "/Users/dappy/.ssh/id_ed25519" ];

    secrets.upcloud_token = { };

    templates."secrets.fish" = {
      owner = "dappy";
      mode = "0400";
      content = ''
        set -x UPCLOUD_TOKEN ${config.sops.placeholder.upcloud_token}
      '';
    };
  };

  programs.fish.shellInit = ''
    test -r "${config.sops.templates."secrets.fish".path}"; and source "${config.sops.templates."secrets.fish".path}"
  '';
}
