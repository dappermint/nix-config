{ lib, ... }:

let
  workspaceKeys = [
    "1"
    "2"
    "3"
    "4"
    "5"
    "6"
    "7"
    "8"
    "9"
    "a"
    "b"
    "c"
    "d"
    "e"
    "f"
    "g"
    "i"
    "m"
    "n"
    "o"
    "p"
    "q"
    "r"
    "s"
    "t"
    "u"
    "v"
    "w"
    "x"
    "y"
    "z"
  ];

  workspaceBindings = lib.mergeAttrsList (
    map (key: {
      "alt-ctrl-${key}" = "workspace ${lib.toUpper key}";
      "alt-ctrl-shift-${key}" = "move-node-to-workspace ${lib.toUpper key}";
    }) workspaceKeys
  );
in
{
  services.aerospace = {
    enable = true;

    settings = {
      config-version = 2;

      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      accordion-padding = 30;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];
      automatically-unhide-macos-hidden-apps = false;

      key-mapping.preset = "qwerty";

      gaps = {
        inner.horizontal = 8;
        inner.vertical = 8;
        outer.left = 8;
        outer.bottom = 8;
        outer.top = 8;
        outer.right = 8;
      };

      mode.main.binding = workspaceBindings // {
        alt-ctrl-slash = "layout tiles horizontal vertical";
        alt-ctrl-comma = "layout accordion horizontal vertical";

        alt-ctrl-h = "focus left";
        alt-ctrl-j = "focus down";
        alt-ctrl-k = "focus up";
        alt-ctrl-l = "focus right";

        alt-ctrl-shift-h = "move left";
        alt-ctrl-shift-j = "move down";
        alt-ctrl-shift-k = "move up";
        alt-ctrl-shift-l = "move right";

        alt-ctrl-minus = "resize smart -50";
        alt-ctrl-equal = "resize smart +50";

        alt-ctrl-tab = "workspace-back-and-forth";
        alt-ctrl-shift-tab = "move-workspace-to-monitor --wrap-around next";

        alt-ctrl-shift-semicolon = "mode service";
      };

      mode.service.binding = {
        esc = [
          "reload-config"
          "mode main"
        ];
        r = [
          "flatten-workspace-tree"
          "mode main"
        ];
        f = [
          "layout floating tiling"
          "mode main"
        ];
        backspace = [
          "close-all-windows-but-current"
          "mode main"
        ];

        alt-ctrl-shift-h = [
          "join-with left"
          "mode main"
        ];
        alt-ctrl-shift-j = [
          "join-with down"
          "mode main"
        ];
        alt-ctrl-shift-k = [
          "join-with up"
          "mode main"
        ];
        alt-ctrl-shift-l = [
          "join-with right"
          "mode main"
        ];
      };
    };
  };
}
