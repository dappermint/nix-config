{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "yes";
        Compression = false;
        # the clownupdate sessions sit silent for minutes while apt runs, and
        # a nat idle timeout mid-upgrade leaves the remote half-applied
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        # reuse the first connection to a host for every later one (lazygit,
        # scp, a second tmux), so only one handshake is paid per host. the
        # master lingers ten minutes after the last client closes
        ControlMaster = "auto";
        ControlPersist = "10m";
        ControlPath = "~/.ssh/cm-%r@%h:%p";
      };

      # throwaway identity for public/anonymous services, never the main key
      "railway.new" = {
        IdentityFile = "~/.ssh/id_ed25519_public";
        IdentitiesOnly = true;
      };

      "ipad 10.25.60.16" = {
        HostName = "10.25.60.16";
        User = "root";
        HostKeyAlgorithms = "+ssh-rsa";
        PubkeyAcceptedKeyTypes = "+ssh-rsa";
      };
    };
  };
}
