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
      };
    };
  };
}
