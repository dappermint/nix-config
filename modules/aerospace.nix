{ ... }:

{
  services.aerospace = {
    enable = true;

    settings = {
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      accordion-padding = 30;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];
      automatically-unhide-macos-hidden-apps = false;

      key-mapping.preset = "qwerty";

      gaps = {
        inner.horizontal = 0;
        inner.vertical = 0;
        outer.left = 0;
        outer.bottom = 0;
        outer.top = 0;
        outer.right = 0;
      };

      mode.main.binding = {
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

        alt-ctrl-1 = "workspace 1";
        alt-ctrl-2 = "workspace 2";
        alt-ctrl-3 = "workspace 3";
        alt-ctrl-4 = "workspace 4";
        alt-ctrl-5 = "workspace 5";
        alt-ctrl-6 = "workspace 6";
        alt-ctrl-7 = "workspace 7";
        alt-ctrl-8 = "workspace 8";
        alt-ctrl-9 = "workspace 9";
        alt-ctrl-a = "workspace A";
        alt-ctrl-b = "workspace B";
        alt-ctrl-c = "workspace C";
        alt-ctrl-d = "workspace D";
        alt-ctrl-e = "workspace E";
        alt-ctrl-f = "workspace F";
        alt-ctrl-g = "workspace G";
        alt-ctrl-i = "workspace I";
        alt-ctrl-m = "workspace M";
        alt-ctrl-n = "workspace N";
        alt-ctrl-o = "workspace O";
        alt-ctrl-p = "workspace P";
        alt-ctrl-q = "workspace Q";
        alt-ctrl-r = "workspace R";
        alt-ctrl-s = "workspace S";
        alt-ctrl-t = "workspace T";
        alt-ctrl-u = "workspace U";
        alt-ctrl-v = "workspace V";
        alt-ctrl-w = "workspace W";
        alt-ctrl-x = "workspace X";
        alt-ctrl-y = "workspace Y";
        alt-ctrl-z = "workspace Z";

        alt-ctrl-shift-1 = "move-node-to-workspace 1";
        alt-ctrl-shift-2 = "move-node-to-workspace 2";
        alt-ctrl-shift-3 = "move-node-to-workspace 3";
        alt-ctrl-shift-4 = "move-node-to-workspace 4";
        alt-ctrl-shift-5 = "move-node-to-workspace 5";
        alt-ctrl-shift-6 = "move-node-to-workspace 6";
        alt-ctrl-shift-7 = "move-node-to-workspace 7";
        alt-ctrl-shift-8 = "move-node-to-workspace 8";
        alt-ctrl-shift-9 = "move-node-to-workspace 9";
        alt-ctrl-shift-a = "move-node-to-workspace A";
        alt-ctrl-shift-b = "move-node-to-workspace B";
        alt-ctrl-shift-c = "move-node-to-workspace C";
        alt-ctrl-shift-d = "move-node-to-workspace D";
        alt-ctrl-shift-e = "move-node-to-workspace E";
        alt-ctrl-shift-f = "move-node-to-workspace F";
        alt-ctrl-shift-g = "move-node-to-workspace G";
        alt-ctrl-shift-i = "move-node-to-workspace I";
        alt-ctrl-shift-m = "move-node-to-workspace M";
        alt-ctrl-shift-n = "move-node-to-workspace N";
        alt-ctrl-shift-o = "move-node-to-workspace O";
        alt-ctrl-shift-p = "move-node-to-workspace P";
        alt-ctrl-shift-q = "move-node-to-workspace Q";
        alt-ctrl-shift-r = "move-node-to-workspace R";
        alt-ctrl-shift-s = "move-node-to-workspace S";
        alt-ctrl-shift-t = "move-node-to-workspace T";
        alt-ctrl-shift-u = "move-node-to-workspace U";
        alt-ctrl-shift-v = "move-node-to-workspace V";
        alt-ctrl-shift-w = "move-node-to-workspace W";
        alt-ctrl-shift-x = "move-node-to-workspace X";
        alt-ctrl-shift-y = "move-node-to-workspace Y";
        alt-ctrl-shift-z = "move-node-to-workspace Z";

        alt-ctrl-tab = "workspace-back-and-forth";
        alt-ctrl-shift-tab = "move-workspace-to-monitor --wrap-around next";

        alt-ctrl-shift-semicolon = "mode service";
      };

      mode.service.binding = {
        esc = [ "reload-config" "mode main" ];
        r = [ "flatten-workspace-tree" "mode main" ];
        f = [ "layout floating tiling" "mode main" ];
        backspace = [ "close-all-windows-but-current" "mode main" ];

        alt-ctrl-shift-h = [ "join-with left" "mode main" ];
        alt-ctrl-shift-j = [ "join-with down" "mode main" ];
        alt-ctrl-shift-k = [ "join-with up" "mode main" ];
        alt-ctrl-shift-l = [ "join-with right" "mode main" ];
      };
    };
  };
}
