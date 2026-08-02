{ config, ... }:

let
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;

  screenshotsDirectory = "${home}/Pictures/Screenshots";
in
{
  system.defaults = {
    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;

    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      AppleICUForce24HourTime = true;

      ApplePressAndHoldEnabled = false;
      KeyRepeat = 2;
      InitialKeyRepeat = 15;

      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticInlinePredictionEnabled = false;

      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;

      "com.apple.swipescrolldirection" = true;
      "com.apple.sound.beep.feedback" = 0;
    };

    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.2;
      orientation = "bottom";
      tilesize = 64;
      mineffect = "genie";
      show-recents = false;
      mru-spaces = false;
      expose-animation-duration = 0.1;
      launchanim = false;
      static-only = false;
      showhidden = true;
    };

    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      FXPreferredViewStyle = "clmv";
      FXEnableExtensionChangeWarning = false;
      FXDefaultSearchScope = "SCcf";
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXShowPosixPathInTitle = true;
      _FXSortFoldersFirst = true;
      QuitMenuItem = true;
      ShowExternalHardDrivesOnDesktop = true;
      ShowRemovableMediaOnDesktop = true;
    };

    screencapture = {
      location = screenshotsDirectory;
      type = "png";
      disable-shadow = true;
    };

    trackpad = {
      Clicking = true;
      TrackpadThreeFingerDrag = true;
      TrackpadRightClick = true;
    };

    loginwindow = {
      GuestEnabled = false;
      SHOWFULLNAME = false;
    };

    WindowManager = {
      EnableStandardClickToShowDesktop = false;
      GloballyEnabled = false;
    };

    controlcenter = {
      BatteryShowPercentage = true;
    };

    menuExtraClock = {
      Show24Hour = true;
      ShowSeconds = true;
      ShowDate = 1;
      ShowDayOfWeek = false;
    };
  };

  system.startup.chime = false;

  system.activationScripts.extraActivation.text = ''
    install -d -o ${user} -g staff "${screenshotsDirectory}"
  '';
}
