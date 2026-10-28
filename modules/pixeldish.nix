{ inputs, ... }:
{
  imports = [ inputs.pixeldish.darwinModules.default ];

  services.pixeldish = {
    enable = true;
    settings.animate = true;
    # the look the brew install had when it moved under nix
    pattern = {
      shape = "Pipes";
      palette = "Van Helsing";
    };
    saved = [
      {
        name = "voronoi iris";
        shape = "Voronoi";
        dither = "Bayer 16";
        palette = "Iris";
        pixelSize = 3;
        warp = 0.2039;
        contrast = 1.0035;
        grain = 0;
        vignette = 0;
        zoom = 0.7;
        spread = 0.0261;
        speed = 0.1992;
        seed = 397.996;
      }
      {
        name = "gargantua";
        shape = "Kerr";
        dither = "Bayer 8";
        palette = "Ember";
        params = {
          spin = 0.95;
          inclination = 84;
        };
      }
    ];
  };
}
