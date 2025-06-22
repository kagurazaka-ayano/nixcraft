{ pkgs, lib, ... }:
let
  mcdr = pkgs.python312.withPackages (ps:
    with ps; [
      mcdreforged
      apscheduler
      fastapi
      hjson
      requests
      sqlalchemy
      uvicorn
      pytz
      xxhash
      zstandard
      nbtlib
    ]);
  leaves_1_20_1 = {
    url =
      "https://github.com/LeavesMC/Leaves/releases/download/1.20.1-847357b/leaves-1.20.1.jar";
    name = "leaves";
    hash = "sha256-cfH5beGJM+ZIzPLQTu0Z8aJAjp/qlH7AcONe85zTQiQ=";
  };
in {
  imports = [
    (import ./objects/server.nix {
      inherit pkgs lib;
      jdk = pkgs.jdk;
      name = "tita-survival";
      kernel = leaves_1_20_1;
      wrapper = {
        root = "server";
        package = mcdr;
        extra_packages = [ ];
        plugins = import ./mcdr/plugins.nix;
        confs = (import ./mcdr/configs.nix) ++ [{
          name = "config.json";
          path = ./mcdr/config/mirror_archive_manager/config_main.json;
          dir = "config/mirror_archive_manager";
        }];
        start_cmd = "${mcdr}/bin/mcdreforged start";
        stop_cmd = "!!MCDR server stop";
      };
      mod_list = [ ];
      mod_dir = "mods";
      plugin_list = import ./plugins.nix;
      conf_list = (import ./configs.nix) ++ [{
        name = "server.properties";
        path = ./configs/server_survival.properties;
        dir = ".";
      }];
      plugin_dir = "plugins";
    })
    (import ./objects/server.nix {
      inherit pkgs lib;
      jdk = pkgs.jdk;
      name = "tita-creative";
      kernel = leaves_1_20_1;
      wrapper = {
        root = "server";
        package = mcdr;
        extra_packages = [ ];
        plugins = import ./mcdr/plugins.nix;
        confs = (import ./mcdr/configs.nix) ++ [{
          name = "config.json";
          path = ./mcdr/config/mirror_archive_manager/config_mirror1.json;
          dir = "config/mirror_archive_manager";
        }];
        start_cmd = "${mcdr}/bin/mcdreforged start";
        stop_cmd = "!!MCDR server stop";
      };
      mod_list = [ ];
      mod_dir = "mods";
      plugin_list = (import ./plugins.nix) ++ [{
        name = "PaperAxiom";
        url =
          "https://cdn.modrinth.com/data/evkiwA7V/versions/DKSjm6Az/AxiomPaper-4.0.5-for-MC1.20.1.jar";
        hash = "sha256-C1YKINzFjZCc8sSRTUYCpmGwgOi2OhtMlkCA7LvwZzc=";
      }];
      conf_list = (import ./configs.nix) ++ [{
        name = "server.properties";
        path = ./configs/server_creative.properties;
        dir = ".";
      }];
      plugin_dir = "plugins";
    })
  ];
}
