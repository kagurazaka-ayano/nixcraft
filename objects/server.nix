{ name, server_root ? "", kernel, wrapper, mod_list, mod_dir, plugin_list
, plugin_dir, conf_list ? [ ], pkgs, lib, start_cmd ? "", stop_cmd ? "", jdk
, ... }:
let
  root = "srv/" + (if server_root != "" then server_root else name);
  use_custom_wrapper = !builtins.isString wrapper;
  server_dir = if use_custom_wrapper then root + "/" + wrapper.root else root;
  propogated_mods = map (mod: mod // { dir = mod_dir; }) mod_list;
  propogated_plugins =
    map (plugin: plugin // { dir = plugin_dir; }) plugin_list;
  kernel_obj = kernel // { dir = "."; };
  wrapper_props =
    if use_custom_wrapper then wrapper // { inherit root; } else "";
  begin_cmd = (if use_custom_wrapper then
    wrapper.start_cmd
  else
    (if start_cmd == "" then throw "Start command is needed" else start_cmd));
  end_cmd = (if use_custom_wrapper then
    wrapper.stop_cmd
  else
    (if stop_cmd == "" then throw "Stop command is needed" else stop_cmd));
  wrapper_package_list = (if (lib.attrsets.isDerivation wrapper.package) then
    [ wrapper.package ]
  else
    let
      values = (lib.attrsets.attrValues wrapper.package);
      der = builtins.filter (p: lib.attrsets.isDerivation p) values;
      file = builtins.filter (p: !lib.attrsets.isDerivation p) values;
    in if (file == [ ]) then
      der
    else
      der ++ lib.lists.map (file: {
        name = file.name;
        value = import ../objects/file.nix { inherit lib pkgs file; };
      }) file);
  packages = [ jdk pkgs.screen ] ++ wrapper_package_list;
in {
  imports = [
    (import ../utils/filelist.nix {
      inherit pkgs lib;
      root = server_dir;
      files = [ kernel_obj ] ++ propogated_mods ++ propogated_plugins
        ++ conf_list;
    })
    (if use_custom_wrapper then
      import ./wrapper.nix {
        inherit pkgs lib;
        props = wrapper_props;
      }
    else
      pkgs.emptyDirectory)
  ];
  programs.screen.enable = true;
  environment.systemPackages = packages;
  systemd.services = {
    "mcserver-${name}" = {
      enable = true;
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        User = "root";
        Group = "root";
        Type = "forking";
        ExecStart = ''
          ${pkgs.runtimeShell} -c "${pkgs.screen}/bin/screen -dmS mcserver-${name} ${begin_cmd}"
        '';
        ExecStop = ''
          ${pkgs.runtimeShell} -c "${pkgs.screen}/bin/screen -S mcserver-${name} -X stuff '${end_cmd}\n'"'';
        RuntimeDirectory = "mcserver-${name}";
        WorkingDirectory = "/etc/${root}";
        RemainAfterExit = false;
        Restart = "always";
        RestartSec = "5s";
        SuccessExitStatus = 1;
      };
      path = [ jdk ] ++ wrapper_package_list;
    };
  };
}
