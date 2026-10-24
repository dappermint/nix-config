{
  config,
  lib,
  pkgs,
  ...
}:

let
  # every https vhost: one cert, one upstream, nothing else
  sites = {
    "home.dappy.lgbt" = "http://127.0.0.1:8123";
    "esphome.dappy.lgbt" = "http://127.0.0.1:6052";
    "id.dappy.lgbt" = "https://127.0.0.1:8443";
    "vault.dappy.lgbt" = "http://127.0.0.1:8222";
    "sync.dappy.lgbt" = "http://127.0.0.1:8384";
    "status.dappy.lgbt" = "http://127.0.0.1:8080";
    "bin.dappy.lgbt" = "http://127.0.0.1:8082";
    "atuin.dappy.lgbt" = "http://127.0.0.1:8888";
    "9r.dappy.lgbt" = "http://127.0.0.1:20128";
  };
  keys = import ../../lib/keys.nix;
  user = "dappy";
in
{
  systemd.services.ninerouter = {
    description = "9router llm proxy";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs._9router}/bin/9router -n -t --skip-update --host 127.0.0.1";
      Restart = "always";
      EnvironmentFile = config.sops.secrets.ninerouter_env.path;
      DynamicUser = true;
      ProtectHome = true;
      StateDirectory = "ninerouter";
      WorkingDirectory = "/var/lib/ninerouter";
    };
    environment = {
      HOME = "/var/lib/ninerouter";
      XDG_DATA_HOME = "/var/lib/ninerouter";
      XDG_CONFIG_HOME = "/var/lib/ninerouter";
    };
  };

  # the c6 runs esp-sdr now (systemd.services.waves), so the KISS radio is off. to go
  # back, re-flash rnode154 and re-enable interfaces.radio
  services.rnsd = {
    enable = true;
    package = pkgs.rsreticulum;
    packageBinaryName = "rnsd-rs";
    extraGroups = [ "dialout" ];
    settings = {
      reticulum = {
        enable_transport = true;
        share_instance = true;
        respond_to_probes = true;
      };
      # eth0 only: eth0-8 is the isolated smart home leg, and AutoInterface on
      # both would bridge the two bridges at the reticulum layer
      interfaces.lan = {
        type = "AutoInterface";
        enabled = true;
        devices = "eth0";
      };
      interfaces.radio = {
        type = "KISSInterface";
        enabled = false;
        port = "/dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_8C:FD:49:1A:05:48-if00";
        speed = 115200;
      };
    };
  };

  # same setup as sbx-intelmac: kanidm behind nginx, provisioned from here
  services.kanidm = {
    server.enable = true;
    package = pkgs.kanidmWithSecretProvisioning_1_11;
    server.settings = {
      domain = "id.dappy.lgbt";
      origin = "https://id.dappy.lgbt";
      bindaddress = "127.0.0.1:8443";
      # only nginx talks to this listener, with verification off, so a renewed
      # cert that kanidm has not reloaded yet breaks nothing
      tls_chain = "/var/lib/acme/home.dappy.lgbt/fullchain.pem";
      tls_key = "/var/lib/acme/home.dappy.lgbt/key.pem";
      online_backup = {
        path = "/var/backup/kanidm";
        versions = 3;
      };
    };
    provision = {
      enable = true;
      instanceUrl = "https://127.0.0.1:8443";
      acceptInvalidCerts = true;
      idmAdminPasswordFile = config.sops.secrets.kanidm_idm_admin_password.path;
      groups.home_users = { };
      persons.dappy = {
        displayName = "Lia Yoffe";
        mailAddresses = [ "dappy@hey.com" ];
        groups = [ "home_users" ];
      };
      systems.oauth2.vaultwarden = {
        displayName = "vaultwarden";
        originUrl = "https://vault.dappy.lgbt/identity/connect/oidc-signin";
        originLanding = "https://vault.dappy.lgbt/";
        basicSecretFile = config.sops.secrets.kanidm_vaultwarden_secret.path;
        preferShortUsername = true;
        scopeMaps.home_users = [
          "openid"
          "profile"
          "email"
        ];
      };
      systems.oauth2.gatus = {
        displayName = "status";
        originUrl = "https://status.dappy.lgbt/authorization-code/callback";
        originLanding = "https://status.dappy.lgbt/";
        basicSecretFile = config.sops.secrets.kanidm_gatus_secret.path;
        # gatus 5.37 sends no code_verifier (security/oidc.go), so kanidm's
        # mandatory pkce would reject every login. confidential client + state
        allowInsecureClientDisablePkce = true;
        scopeMaps.home_users = [ "openid" ];
      };
    };
  };

  users.users.kanidm.extraGroups = [ "nginx" ];

  services.vaultwarden = {
    enable = true;
    # nightly sqlite .backup snapshot, picked up by the garage backup at 04:00
    backupDir = "/var/backup/vaultwarden";
    environmentFile = config.sops.templates."vaultwarden.env".path;
    config = {
      DOMAIN = "https://vault.dappy.lgbt";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      SIGNUPS_ALLOWED = false;
      SSO_ENABLED = true;
      SSO_ONLY = true;
      SSO_CLIENT_ID = "vaultwarden";
      SSO_AUTHORITY = "https://id.dappy.lgbt/oauth2/openid/vaultwarden";
    };
  };

  services.syncthing = {
    enable = true;
    guiPasswordFile = config.sops.secrets.syncthing_gui_password.path;
    # devices and folders get paired from the gui; the defaults would delete
    # them again on every restart
    overrideDevices = false;
    overrideFolders = false;
    settings.gui = {
      inherit user;
      # nginx forwards Host: sync.dappy.lgbt, which the gui's dns-rebinding
      # check rejects. the gui password is what guards it
      insecureSkipHostcheck = true;
    };
  };

  # runs outside conway on purpose, so it still sees conway going down
  services.gatus = {
    enable = true;
    environmentFile = config.sops.templates."gatus.env".path;
    settings = {
      web = {
        address = "127.0.0.1";
        port = 8080;
      };
      security.oidc = {
        issuer-url = "https://id.dappy.lgbt/oauth2/openid/gatus";
        redirect-url = "https://status.dappy.lgbt/authorization-code/callback";
        client-id = "gatus";
        client-secret = "\${GATUS_OIDC_SECRET}";
        scopes = [ "openid" ];
      };
      endpoints = [
        {
          name = "abode";
          group = "home";
          url = "https://home.dappy.lgbt/api/";
          # one cert covers every *.dappy.lgbt name here, so this also catches
          # a failed acme renewal
          conditions = [
            "[STATUS] == 200"
            "[CERTIFICATE_EXPIRATION] > 240h"
          ];
        }
        {
          name = "esphome";
          group = "home";
          url = "https://esphome.dappy.lgbt/";
          conditions = [ "[STATUS] == 200" ];
        }
        {
          name = "kanidm";
          group = "home";
          url = "https://id.dappy.lgbt/status";
          conditions = [ "[STATUS] == 200" ];
        }
        {
          name = "vaultwarden";
          group = "home";
          url = "https://vault.dappy.lgbt/alive";
          conditions = [ "[STATUS] == 200" ];
        }
        {
          name = "syncthing";
          group = "home";
          url = "https://sync.dappy.lgbt/rest/noauth/health";
          conditions = [ "[STATUS] == 200" ];
        }
        {
          name = "atuin";
          group = "home";
          url = "https://atuin.dappy.lgbt/";
          conditions = [ "[STATUS] == 200" ];
        }
        {
          name = "router";
          group = "home";
          url = "icmp://10.14.88.1";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "k8s api";
          group = "conway";
          url = "tcp://100.120.79.74:6443";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "garage s3";
          group = "conway";
          url = "tcp://100.80.221.44:3900";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "sandb0x.space";
          group = "sbx";
          url = "https://sandb0x.space";
          conditions = [ "[STATUS] == 200" ];
        }
      ];
    };
  };

  # both fetch oidc discovery from kanidm through nginx at startup
  systemd.services.gatus.after = [
    "kanidm.service"
    "nginx.service"
  ];

  systemd.services.vaultwarden.after = [
    "kanidm.service"
    "nginx.service"
  ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "dappy@hey.com";
    certs."home.dappy.lgbt" = {
      dnsProvider = "cloudflare";
      # the router answers *.dappy.lgbt from static records for split horizon,
      # so a propagation check through it never sees cloudflare's txt record
      dnsResolver = "1.1.1.1:53";
      environmentFile = "/var/lib/acme/cf-token";
      group = "nginx";
      extraDomainNames = lib.remove "home.dappy.lgbt" (lib.attrNames sites);
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts =
      lib.mapAttrs (_: upstream: {
        useACMEHost = "home.dappy.lgbt";
        forceSSL = true;
        locations."/" = {
          proxyPass = upstream;
          proxyWebsockets = true;
          extraConfig = ''
            if ($http_content_encoding ~* br) { return 415; }
          '';
        };
      }) sites
      // {
        "waves.petahtikva.lan".locations."/" = {
          proxyPass = "http://127.0.0.1:8090";
          extraConfig = "proxy_buffering off;";
        };
      };
  };

  services.atuin = {
    enable = true;
    database = {
      createLocally = false;
      uri = "sqlite:///var/lib/atuin/atuin.db";
    };
  };

  systemd.services.atuin.serviceConfig.StateDirectory = "atuin";

  services.microbin = {
    enable = true;
    settings = {
      MICROBIN_BIND = "127.0.0.1";
      MICROBIN_PORT = 8082;
      MICROBIN_PUBLIC_PATH = "https://bin.dappy.lgbt/";
      MICROBIN_READONLY = false;
      MICROBIN_QR = true;
      MICROBIN_ENABLE_BURN_AFTER = true;
      MICROBIN_DEFAULT_EXPIRY = "24h";
    };
  };

  # nothing opens its ports on eth0, so it is reachable over the tailnet only
  services.soft-serve = {
    enable = true;
    settings = {
      name = "gotham";
      anon-access = "no-access";
      allow-keyless = false;
      initial_admin_keys = [ keys.ed25519 ];
      ssh = {
        listen_addr = ":23231";
        # the short magicdns name, not the full tail*.ts.net one: it
        # resolves the same on the tailnet and keeps the tailnet id out of
        # a public repo
        public_url = "ssh://gotham:23231";
      };
      http = {
        listen_addr = "127.0.0.1:23232";
        public_url = "http://127.0.0.1:23232";
      };
      git.listen_addr = "127.0.0.1:9418";
      stats.listen_addr = "127.0.0.1:23233";
    };
  };

  # the module's ExecPaths points at repos/, which does not exist on first
  # start, so the mount namespace setup fails before soft-serve can create it
  systemd.services.soft-serve.serviceConfig.StateDirectory = lib.mkForce [
    "soft-serve"
    "soft-serve/repos"
  ];
}
