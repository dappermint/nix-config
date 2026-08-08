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
      AppleKeyboardUIMode = 3;

      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticInlinePredictionEnabled = false;

      NSDocumentSaveNewDocumentsToCloud = false;
      NSWindowShouldDragOnGesture = true;
      NSAutomaticWindowAnimationsEnabled = false;
      NSWindowResizeTime = 0.001;

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
      mineffect = "scale";
      show-recents = false;
      appswitcher-all-displays = true;
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
      FXRemoveOldTrashItems = true;
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

    screensaver = {
      askForPassword = true;
      askForPasswordDelay = 0;
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

    CustomUserPreferences = {
      NSGlobalDomain = {
        QLPanelAnimationDuration = 0.0;
        NSToolbarTitleViewRolloverDelay = 0.0;
      };
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.finder".DisableAllAnimations = true;
      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
        allowIdentifierForAdvertising = false;
        forceLimitAdTracking = true;
      };
      "com.apple.CrashReporter".DialogType = "none";
      "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
    };
  };

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  networking.applicationFirewall = {
    enable = true;
    enableStealthMode = true;
  };

  system.startup.chime = false;

  system.activationScripts.extraActivation.text = ''
    install -d -o ${user} -g staff "${screenshotsDirectory}"

    defaults write "/Library/Application Support/CrashReporter/DiagnosticMessagesHistory.plist" AutoSubmit -bool false
    defaults write "/Library/Application Support/CrashReporter/DiagnosticMessagesHistory.plist" ThirdPartyDataSubmit -bool false
  '';
}
