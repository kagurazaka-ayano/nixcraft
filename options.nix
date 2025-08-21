# ./options.nix
{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption mkOptionType;
  types = lib.types;

  BaseFile = {
    name = mkOption {
      type = types.str;
      description = "name of the file that you want to store locally";
    };
    suffix = mkOption {
      type = types.str;
      description = "suffix of the file, with or without the preceding dot. If the name contain a valid suffix this will be ignored";
      default = "";
    };
    dest = mkOption {
      type = types.str;
      description = "the destination of this file";
    };
  };
  RemoteFile = mkOptionType {
    name = "remoteFile";
    description = "a remote file, with url";
    check = types.submodule {
      options =
        BaseFile
        // {
          url = mkOption {
            type = types.str;
            description = "url of the remote file, must be a direct link to the file (API is not accepted)";
          };
          hash = mkOption {
            type = types.str;
            description = "hash of remote file";
          };
        };
    };
    merge = types.mergeEqualOption;
  };
  LocalFile = mkOptionType {
    name = "localFile";
    description = "a local file, with absolute path pointing to that file";
    check = types.submodule {
      options =
        BaseFile
        // {
          path = mkOption {
            type = types.path;
            description = "absolute path of the local file";
          };
        };
    };
  };
  FileType = mkOptionType {
    name = "genericFile";
    description = "a generic file type, can be either local or remote";
    check = types.oneOf [LocalFile RemoteFile];
    merge = types.mergeEqualOption;
  };
  Wrapper = mkOptionType {
    name = "wrapper";
    description = "a custom server wrapper, that will handle server operation(such as launching/event handling)";
    check = types.submodule {
      options = {
        root = mkOption {
          type = types.str;
          description = "Where the server file will be located, also the position of the server kernel";
        };
        package = mkOption {
          type = types.oneOf [(types.listOf types.package) types.package];
          description = "the dependencies of the server wrapper, could be runtime env or the exec itself, will be installed when the systemd service starts";
        };
        plugins = mkOption {
          type = types.listOf FileType;
          description = "plugins for the wrapper";
        };
        confs = mkOption {
          type = types.listOf FileType;
          description = "config files for the wrapper";
        };
        start_cmd = mkOption {
          type = types.str;
          description = "command that starts the server, will be executed by the screen session";
          example = ''''${pkgs.mcdreforged}/bin/mcdreforged start'';
        };
        stop_cmd = mkOption {
          type = types.str;
          description = "command that stops the server, will be piped into the stdin of the screen session";
          example = "!!MCDR server stop";
        };
      };
    };
    merge = types.mergeEqualOption;
  };

  Server = mkOptionType {
    name = "server";
    description = "A server instance";
    check = types.submodule ({config, ...}: {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to enable this server instance.";
        };
        name = mkOption {
          type = types.str;
          description = "server name, will be used in service creation, screen session naming, and directory naming";
          example = "mcserver-nix";
        };
        user = mkOption {
          type = types.str;
          default = config.services.mcservers.user;
          description = "User to run this server instance as.";
        };
        group = mkOption {
          type = types.str;
          default = config.services.mcservers.group;
          description = "Group to run this server instance as.";
        };
        jdk = mkOption {
          type = types.package;
          description = "The server java environment";
          default = pkgs.jdk;
        };
        kernel = mkOption {
          type = FileType;
          description = "The server kernel jar";
        };
        launch = mkOption {
          type = types.oneOf [Wrapper types.str];
          description = "server wrapper object or the start command";
        };
        stop = mkOption {
          type = types.nullOr types.str;
          description = "server stop command, can be unspecified if the item given in the launch attribute is a Wrapper";
          default = null;
        };
        mod_dir = mkOption {
          type = types.str;
          default = "mods";
          description = "Relative path from the server root for all mods in `mod_list`.";
        };
        mod_list = mkOption {
          type = types.listOf FileType;
          default = [];
          description = "List of mods to be placed in `mod_dir`.";
        };

        config_dir = mkOption {
          type = types.str;
          default = ".";
          description = "Relative path from the server root for all config files in `config_list`.";
        };
        config_list = mkOption {
          type = types.listOf FileType;
          default = [];
          description = "List of config files to be placed in `config_dir`.";
        };
      };

      assertions = [
        {
          assertion = !(lib.isString config.launch && config.stop == null);
          message = "When `launch` is a string (not a Wrapper), the `stop` option must be set.";
        }
      ];
    });
  };
in {
  services.mcservers = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the declarative mcservers module.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/mcservers";
      description = "The root directory for all server instance data.";
    };

    user = mkOption {
      type = types.str;
      default = "mcserver";
      description = "Default user to run server instances as.";
    };

    group = mkOption {
      type = types.str;
      default = "mcserver";
      description = "Default group to run server instances as.";
    };

    servers = mkOption {
      type = types.attrsOf Server;
      default = {};
      example = {
        /*
        ...
        */
      };
      description = "Declarative Minecraft (or other) server instances.";
    };
  };
}
