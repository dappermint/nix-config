{
  lib,
  pkgs,
  primaryHomeDirectory,
  ...
}:

let
  profileName = "Lectures";
  collectionName = "Lectures";

  obsDir = "${primaryHomeDirectory}/Library/Application Support/obs-studio";
  profileDir = "${obsDir}/basic/profiles/${profileName}";
  sceneFile = "${obsDir}/basic/scenes/${collectionName}.json";
  recordingDir = "${primaryHomeDirectory}/Movies/Lectures";
  streamKeyFile = "${primaryHomeDirectory}/.config/obs/youtube-stream-key";

  width = 1920;
  height = 1080;
  fps = 30;

  # obs stamps the writing version here, 0x20020001 is 32.2.1
  prevVer = 537001985;
  mainCanvasUuid = "6c69626f-6273-4c00-9d88-c5136d61696e";

  sourceBase = {
    prev_ver = prevVer;
    mixers = 0;
    sync = 0;
    flags = 0;
    volume = 1.0;
    balance = 0.5;
    enabled = true;
    muted = false;
    "push-to-mute" = false;
    "push-to-mute-delay" = 0;
    "push-to-talk" = false;
    "push-to-talk-delay" = 0;
    deinterlace_mode = 0;
    deinterlace_field_order = 0;
    monitoring_type = 0;
    private_settings = { };
  };

  mkFilter =
    {
      name,
      id,
      uuid,
      settings,
    }:
    sourceBase
    // {
      inherit
        name
        id
        uuid
        settings
        ;
    };

  # webcam framerate follows the device under a session preset, so both cams
  # land on 1080p and obs never renegotiates mid-lecture
  mkCamera =
    cam:
    sourceBase
    // {
      inherit (cam) name uuid;
      id = "macos-avcapture";
      settings = {
        inherit (cam) device;
        device_name = cam.deviceName;
        use_preset = true;
        preset = "AVCaptureSessionPreset1920x1080";
        buffering = false;
        enable_audio = false;
      };
      hotkeys = { };
    };

  mkScene =
    cam:
    sourceBase
    // {
      name = cam.scene;
      uuid = cam.sceneUuid;
      id = "scene";
      versioned_id = "scene";
      canvas_uuid = mainCanvasUuid;
      settings = {
        id_counter = 1;
        custom_size = false;
        items = [
          {
            inherit (cam) name;
            source_uuid = cam.uuid;
            id = 1;
            visible = true;
            locked = false;
            rot = 0.0;
            pos = {
              x = 0.0;
              y = 0.0;
            };
            scale = {
              x = 1.0;
              y = 1.0;
            };
            align = 5;
            bounds_type = 2;
            bounds_align = 0;
            bounds_crop = false;
            bounds = {
              x = width * 1.0;
              y = height * 1.0;
            };
            crop_left = 0;
            crop_top = 0;
            crop_right = 0;
            crop_bottom = 0;
            group_item_backup = false;
            scale_filter = "disable";
            blend_method = "default";
            blend_type = "normal";
            show_transition.duration = 0;
            hide_transition.duration = 0;
            private_settings = { };
          }
        ];
      };
      hotkeys."OBSBasic.SelectScene" = [
        {
          key = cam.hotkey;
          control = true;
          alt = true;
        }
      ];
    };

  # obs registers mute/unmute as a hotkey pair, so binding one combo to both
  # halves makes it a toggle. the two mics start in opposite states, which turns
  # the single combo into an a/b switch between them
  micToggle = [
    {
      key = "OBS_KEY_M";
      control = true;
      alt = true;
    }
  ];

  mkMic =
    mic:
    sourceBase
    // {
      inherit (mic) name uuid muted;
      id = "coreaudio_input_capture";
      versioned_id = "coreaudio_input_capture";
      settings.device_id = mic.device;
      mixers = 255;
      hotkeys = {
        "libobs.mute" = micToggle;
        "libobs.unmute" = micToggle;
        "libobs.push-to-mute" = [ ];
        "libobs.push-to-talk" = [ ];
      };
      filters = [
        (mkFilter {
          name = "Noise Suppression";
          id = "noise_suppress_filter";
          uuid = mic.filters.suppress;
          settings.method = "rnnoise";
        })
        (mkFilter {
          name = "Compressor";
          id = "compressor_filter";
          uuid = mic.filters.compressor;
          settings = {
            ratio = 4.0;
            threshold = -18.0;
            attack_time = 6;
            release_time = 60;
            output_gain = 3.0;
            sidechain_source = "none";
          };
        })
        (mkFilter {
          name = "Limiter";
          id = "limiter_filter";
          uuid = mic.filters.limiter;
          settings = {
            threshold = -3.0;
            release_time = 60;
          };
        })
      ];
    };

  cameras = [
    {
      name = "Cam - Logitech C922";
      uuid = "d7a0c5d0-6a6c-405d-aa52-c8f7ccb5292c";
      device = "0x1134000046d085c";
      deviceName = "C922 Pro Stream Webcam";
      scene = "Logitech";
      sceneUuid = "75b18a6d-6ee0-454a-ad75-9e06590c678e";
      hotkey = "OBS_KEY_1";
    }
    {
      name = "Cam - MacBook";
      uuid = "50059aba-af52-4dbc-99c7-78c1ce746f0d";
      device = "6C707041-05AC-0011-0002-000000000001";
      deviceName = "MacBook Pro Camera";
      scene = "MacBook";
      sceneUuid = "261fed87-8ced-46d9-b2f3-a5c68bc2be4d";
      hotkey = "OBS_KEY_2";
    }
  ];

  mics = [
    {
      name = "Mic - MacBook";
      uuid = "92c8bf11-ad23-4b48-895c-ec6318eb6bac";
      device = "BuiltInMicrophoneDevice";
      muted = false;
      filters = {
        suppress = "2394f34b-c50f-46d9-b982-ec1301575b2d";
        compressor = "d4652e23-a334-4bfb-bdad-ed08d70f96ca";
        limiter = "335ab2e8-3304-4bb8-8616-88d294bad8bf";
      };
    }
    {
      name = "Mic - BlackShark";
      uuid = "a199d4bc-d105-4854-9e60-b23e86dd66ac";
      device = "AppleUSBAudioEngine:Razer Inc:BlackShark V3 Pro:0000000000000000:2,1";
      muted = true;
      filters = {
        suppress = "997cb8cc-709d-4e21-83b2-42a15c5d9b0b";
        compressor = "43027577-8f01-4777-be24-34d2f5504d1e";
        limiter = "6db6cff2-8f8f-4774-aa52-54d3f4d72e22";
      };
    }
  ];

  sceneCollection = {
    name = collectionName;
    version = 2;

    sources = (map mkCamera cameras) ++ (map mkScene cameras);
    groups = [ ];
    scene_order = map (cam: { name = cam.scene; }) cameras;
    current_scene = (builtins.head cameras).scene;
    current_program_scene = (builtins.head cameras).scene;
    canvases = [ ];

    AuxAudioDevice1 = mkMic (builtins.elemAt mics 0);
    AuxAudioDevice2 = mkMic (builtins.elemAt mics 1);

    DesktopAudioDevice1 = sourceBase // {
      name = "Desktop Audio";
      uuid = "95337890-4cee-4ae7-90d7-bc23bfbb49c5";
      id = "coreaudio_output_capture";
      versioned_id = "coreaudio_output_capture";
      settings.device_id = "default";
      mixers = 255;
      muted = true;
      hotkeys = {
        "libobs.mute" = [ ];
        "libobs.unmute" = [ ];
        "libobs.push-to-mute" = [ ];
        "libobs.push-to-talk" = [ ];
      };
    };

    current_transition = "Fade";
    transition_duration = 300;
    transitions = [ ];
    quick_transitions = [
      {
        name = "Cut";
        duration = 300;
        hotkeys = [ ];
        id = 1;
        fade_to_black = false;
      }
      {
        name = "Fade";
        duration = 300;
        hotkeys = [ ];
        id = 2;
        fade_to_black = false;
      }
    ];

    saved_projectors = [ ];
    preview_locked = false;
    scaling_enabled = false;
    scaling_level = -5;
    scaling_off_x = 0.0;
    scaling_off_y = 0.0;
    virtual-camera.type2 = 3;
  };

  sceneJson = pkgs.writeText "obs-${collectionName}.json" (builtins.toJSON sceneCollection);

  basicIni = pkgs.writeText "obs-${profileName}-basic.ini" ''
    [General]
    Name=${profileName}

    [Output]
    Mode=Simple

    [Video]
    BaseCX=${toString width}
    BaseCY=${toString height}
    OutputCX=${toString width}
    OutputCY=${toString height}
    FPSType=0
    FPSCommon=${toString fps}
    ScaleType=bicubic
    ColorFormat=NV12
    ColorSpace=709
    ColorRange=Partial
    SdrWhiteLevel=300
    HdrNominalPeakLevel=1000

    [Audio]
    SampleRate=48000
    ChannelSetup=Stereo
    MeterDecayRate=23.53
    PeakMeterType=0

    [SimpleOutput]
    FilePath=${recordingDir}
    RecFormat2=hybrid_mp4
    VBitrate=6000
    ABitrate=160
    UseAdvanced=false
    StreamEncoder=apple_h264
    RecEncoder=apple_h264
    RecQuality=HQ
    RecTracks=1
    RecRB=false
  '';

  serviceTemplate = pkgs.writeText "obs-${profileName}-service.json" (
    builtins.toJSON {
      type = "rtmp_common";
      settings = {
        service = "YouTube - RTMPS";
        protocol = "RTMPS";
        server = "rtmps://a.rtmps.youtube.com:443/live2";
        key = "@STREAM_KEY@";
        bwtest = false;
      };
    }
  );

  # obs owns the rest of user.ini (window geometry, dock state), so only the
  # keys that select our managed profile and collection get merged in
  userIniPatch = pkgs.writeText "obs-user-ini-patch.py" ''
    import configparser
    import os
    import sys

    path = sys.argv[1]
    wanted = {
        "Basic": {
            "Profile": "${profileName}",
            "ProfileDir": "${profileName}",
            "SceneCollection": "${collectionName}",
            "SceneCollectionFile": "${collectionName}.json",
        },
    }

    cfg = configparser.RawConfigParser()
    cfg.optionxform = str
    if os.path.exists(path):
        cfg.read(path)

    for section, options in wanted.items():
        if not cfg.has_section(section):
            cfg.add_section(section)
        for key, value in options.items():
            cfg.set(section, key, value)

    with open(path, "w") as handle:
        cfg.write(handle, space_around_delimiters=False)
  '';

  installConfig = pkgs.writeShellApplication {
    name = "obs-install-config";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
      pkgs.python3
    ];
    text = ''
      mkdir -p "${profileDir}" "${obsDir}/basic/scenes" "${recordingDir}"
      install -m 0644 "${basicIni}" "${profileDir}/basic.ini"
      install -m 0644 "${sceneJson}" "${sceneFile}"

      if [ -r "${streamKeyFile}" ]; then
        key=$(tr -d '[:space:]' < "${streamKeyFile}")
        umask 077
        sed "s|@STREAM_KEY@|$key|" "${serviceTemplate}" > "${profileDir}/service.json"
      elif [ ! -e "${profileDir}/service.json" ]; then
        umask 077
        sed "s|@STREAM_KEY@||" "${serviceTemplate}" > "${profileDir}/service.json"
        echo "obs: no stream key at ${streamKeyFile}, wrote service.json without one" >&2
      fi

      python3 "${userIniPatch}" "${obsDir}/user.ini"
    '';
  };
in
{
  home.activation.obsStudioConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe installConfig}
  '';
}
