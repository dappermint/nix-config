{ config, lib, ... }:

let
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;

  screenshotsDirectory = "${home}/Pictures/Screenshots";

  # carbon keycodes and modifier masks, in order: opt+cmd+4, opt+cmd+3,
  # ctrl+opt+cmd+o. reinstalling the cask wipes these, hence pinning them
  shottrShortcuts = {
    KeyboardShortcuts_area = ''{"carbonKeyCode":21,"carbonModifiers":2304}'';
    KeyboardShortcuts_fullscreen = ''{"carbonKeyCode":20,"carbonModifiers":2304}'';
    KeyboardShortcuts_ocr = ''{"carbonKeyCode":31,"carbonModifiers":6400}'';
  };

  asUser = ''launchctl asuser "$(id -u -- ${user})" sudo --user=${user} --'';
in
{
  system.defaults = {
    # never restart unattended for a full os update: this box is also the ci
    # runner. security responses and xprotect data still install themselves
    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

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
      NewWindowTarget = "Home";
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

    CustomSystemPreferences."/Library/Preferences/com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true;
      AutomaticDownload = true;
      CriticalUpdateInstall = true;
      ConfigDataInstall = true;
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
      "com.apple.bird"."optimize-storage" = false;
      "com.apple.SetupAssistant" = {
        DidSeeCloudSetup = true;
        DidSeeiCloudLoginForStorageServices = true;
      };
      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
        allowIdentifierForAdvertising = false;
        forceLimitAdTracking = true;
      };
      "com.apple.CrashReporter".DialogType = "none";
      "com.apple.sharingd".DiscoverableMode = "Contacts Only";
      "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;

      # cc.ffitch.shottr cannot live here: CustomUserPreferences aborts
      # activation on write failure, and its container rejects every writer.
      # applied best-effort in extraActivation from shottrShortcuts instead
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

    # shottr stores prefs in an app-sandbox container that SIP shields from
    # every writer lacking full disk access, root included. re-applied on each
    # switch so it self-heals the moment FDA is granted, and never fatal:
    # CustomUserPreferences would abort the whole activation on this failure
    shottrOk=1
    ${asUser} defaults write cc.ffitch.shottr KeyboardShortcuts_area -string ${lib.escapeShellArg shottrShortcuts.KeyboardShortcuts_area} 2>/dev/null || shottrOk=0
    ${asUser} defaults write cc.ffitch.shottr KeyboardShortcuts_fullscreen -string ${lib.escapeShellArg shottrShortcuts.KeyboardShortcuts_fullscreen} 2>/dev/null || shottrOk=0
    ${asUser} defaults write cc.ffitch.shottr KeyboardShortcuts_ocr -string ${lib.escapeShellArg shottrShortcuts.KeyboardShortcuts_ocr} 2>/dev/null || shottrOk=0
    if [ "$shottrOk" -eq 0 ]; then
      echo "shottr: container not writable, shortcuts left as-is (grant full disk access to enforce)" >&2
    fi

    # SetupAssistant replays the iCloud sign-in pane whenever this lags the
    # running macOS version, so keep it pinned to whatever we booted
    ${asUser} defaults write com.apple.SetupAssistant LastSeenCloudProductVersion -string "$(sw_vers -productVersion)"
  '';

  system.activationScripts.postActivation.text = ''
    pkill -HUP socketfilterfw 2>/dev/null || true
  '';
}
