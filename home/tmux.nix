# rubicon only for now. a phone terminal has no window manager to split, and
# touch scrolling needs mouse mode on or the scrollback is unreachable
{
  programs.tmux = {
    enable = true;

    # C-b needs two hands on a soft keyboard; C-a is reachable with a thumb
    prefix = "C-a";
    mouse = true;
    baseIndex = 1;
    historyLimit = 50000;
    keyMode = "vi";
    terminal = "tmux-256color";

    extraConfig = ''
      set -g renumber-windows on
      set -g set-clipboard on
      # pass the pane's title (fish sets it to the running command) through
      # to the terminal, otherwise the app's tab label freezes on "tmux"
      set -g set-titles on
      set -g set-titles-string "#T"
      set -ga terminal-overrides ",*256col*:Tc"

      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind r source-file ~/.config/tmux/tmux.conf \; display "reloaded"

      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # the status bar costs a whole row on a screen that has very few
      set -g status-style "bg=default,fg=colour245"
      set -g status-left "#[fg=colour39,bold]#S "
      set -g status-right "#[fg=colour245]%H:%M"
      set -g status-justify left
      set -g window-status-current-style "fg=colour39,bold"
    '';
  };
}
