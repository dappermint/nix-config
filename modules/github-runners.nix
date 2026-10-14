{
  config,
  pkgs,
  lib,
  ...
}:

let
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;

  package = pkgs.github-runner;

  shell = import ../lib/shell.nix;

  # what the wine workflows actually invoke. providing them here is not just
  # convenience: the runner is this machine, and `brew install` on it would
  # both pollute the system and get reaped again by brew cleanup = uninstall.
  #
  # the mingw cross compilers are deliberately NOT here. the PE half must be
  # built by the same brew mingw-w64 the hosted runners use, declared in
  # modules/homebrew.nix; nixpkgs' mingw needs a NIX_LDFLAGS that only exists
  # inside a nix build and would fail every PE link. measured 2026-08-04: a
  # kernelbase.dll built by llvm-mingw makes steam loop on its CM login
  # forever, and the same tree with a gcc-built kernelbase.dll logs in within
  # 30 seconds, so the PE toolchain does not get varied casually. see
  # Gaems/frankea-base-recipe.md for the bisect.
  toolPath = lib.makeBinPath [
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.findutils
    pkgs.git
    pkgs.gnutar
    pkgs.gzip
    pkgs.xz
    pkgs.curl
    pkgs.ccache
    pkgs.bison
    pkgs.flex
    pkgs.pkg-config
    config.nix.package
  ];

  fullPath = "${toolPath}:${config.homebrew.prefix}/bin:/usr/bin:/bin:/usr/sbin:/sbin";

  stateDir = repo: "${home}/.local/share/github-runner/${repo}";

  runnerScript =
    repo:
    pkgs.writeShellApplication {
      name = "github-runner-${repo}";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.findutils
      ];
      text = ''
        ${shell.rotateLog}
        rotate_log ${lib.escapeShellArg "${home}/Library/Logs/github-runner-${repo}.log"}
        rotate_log ${lib.escapeShellArg "${home}/Library/Logs/github-runner-${repo}.err.log"}

        export RUNNER_ROOT=${lib.escapeShellArg (stateDir repo)}
        work="$RUNNER_ROOT/_work"
        mkdir -p "$RUNNER_ROOT" "$work"

        find "$work" -mindepth 1 -delete

        # config.sh only runs when the runner is not registered yet, which is
        # why a registration token being valid for an hour is survivable: it is
        # spent once. mint a fresh one with
        #   gh api -X POST /repos/dappermint/${repo}/actions/runners/registration-token
        # before deleting .runner or registering on a new machine.
        # the token rides in on the env var config.sh derives from the
        # ACTIONS_RUNNER_INPUT_ prefix, so it never appears in ps
        if [ ! -f "$RUNNER_ROOT/.runner" ]; then
          ACTIONS_RUNNER_INPUT_TOKEN="$(cat ${config.sops.secrets."github_runner_token_${repo}".path})" \
            ${package}/bin/config.sh \
            --unattended --disableupdate --replace \
            --work "$work" \
            --url https://github.com/dappermint/${repo} \
            --name apollo-${repo} \
            --labels m5
        fi

        exec ${package}/bin/Runner.Listener run --startuptype service
      '';
    };

  # an agent, not a daemon. a launchd daemon lives in the system bootstrap
  # namespace and cannot reach WindowServer, so wine's mac driver fails to load
  # and every job that opens a window dies with
  #   nodrv_CreateWindow Application tried to create a window, but no driver
  # measured 2026-08-05 on run 30970113596: message-only windows fine, every
  # top level window NULL. the wine builds gate on opening a real window, so
  # the runner has to live in the user's Aqua session.
  runnerAgent = repo: {
    serviceConfig = {
      Label = "org.${user}.github-runner-${repo}";
      ProgramArguments = [ "${runnerScript repo}/bin/github-runner-${repo}" ];
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 30;
      ProcessType = "Interactive";
      StandardOutPath = "${home}/Library/Logs/github-runner-${repo}.log";
      StandardErrorPath = "${home}/Library/Logs/github-runner-${repo}.err.log";
      EnvironmentVariables = {
        HOME = stateDir repo;
        RUNNER_ROOT = stateDir repo;
        PATH = fullPath;
      };
    };
  };

  repos = [
    "wine-gptk"
    "winecx-gptk"
  ];

  runnerSecret = {
    owner = user;
    mode = "0400";
  };
in
{
  sops.secrets = lib.listToAttrs (
    map (repo: lib.nameValuePair "github_runner_token_${repo}" runnerSecret) repos
  );

  launchd.user.agents = lib.listToAttrs (
    map (repo: lib.nameValuePair "github-runner-${repo}" (runnerAgent repo)) repos
  );

  system.activationScripts.extraActivation.text = lib.mkAfter (
    lib.concatMapStringsSep "\n" (repo: ''
      install -d -o ${user} -g staff ${lib.escapeShellArg (stateDir repo)}
    '') repos
  );
}
