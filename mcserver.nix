# ./mcserver.nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.mcservers;

  processFile = file:
    if (file ? "url")
    then
      pkgs.fetchurl {
        url = file.url;
        hash = file.hash;
        name =
          if !(lib.strings.hasSuffix "${file.suffix}" file.name)
          then "${file.name}${file.suffix}"
          else file.name;
      }
    else file.path;

  buildDeclarativeRoot = name: serverCfg: let
    isWrapper = isAttrs serverCfg.launch;
    kernelDest =
      if isWrapper
      then serverCfg.launch.root
      else ".";
    kernelFile = serverCfg.kernel;
    kernelLink = {
      name =
        if kernelDest == "."
        then kernelFile.name
        else "${kernelDest}/${kernelFile.name}";
      path = processFile kernelFile;
    };
    modLinks =
      map (modFile: {
        name = "${serverCfg.mod_dir}/${modFile.name}";
        path = processFile modFile;
      })
      serverCfg.mod_list;
    configLinks =
      map (configFile: {
        name = "${serverCfg.config_dir}/${configFile.name}";
        path = processFile configFile;
      })
      serverCfg.config_list;
    wrapperFiles =
      if isWrapper
      then serverCfg.launch.plugins ++ serverCfg.launch.confs
      else [];
    wrapperLinks =
      map (wFile: {
        name = "${wFile.dest}/${wFile.name}";
        path = processFile wFile;
      })
      wrapperFiles;
    allLinks = [kernelLink] ++ modLinks ++ configLinks ++ wrapperLinks;
  in
    pkgs.linkFarm "declarative-root-${name}" allLinks;
in {
  imports = [./options.nix];

  config = mkIf cfg.enable {
    # 1. 创建用户和组
    users.users."${cfg.user}" = {
      isSystemUser = true;
      group = cfg.group;
      description = "System user for mcserver instances";
      home = cfg.dataDir;
    };
    users.groups."${cfg.group}" = {};
    systemd.services =
      mapAttrs' (
        name: serverCfg: let
          isWrapper = isAttrs serverCfg.launch;
          declarativeRoot = buildDeclarativeRoot name serverCfg;
          serverDataDir = "${cfg.dataDir}/${name}";
          workingDir =
            if isWrapper
            then "${serverDataDir}/${serverCfg.launch.root}"
            else serverDataDir;
          startCmd =
            if isWrapper
            then serverCfg.launch.start_cmd
            else serverCfg.launch;
          stopCmd =
            if isWrapper
            then serverCfg.launch.stop_cmd
            else serverCfg.stop;
          wrapperPackages =
            if isWrapper
            then toList serverCfg.launch.package
            else [];
          requiredPackages = [pkgs.screen serverCfg.jdk] ++ wrapperPackages;

          # 准备脚本现在可以简化，因为它总是链接到 serverDataDir 的根
          setupScript = pkgs.writeShellScript "mcserver-${name}-setup.sh" ''
            #!${pkgs.runtimeShell}
            set -e
            mkdir -p "${serverDataDir}"
            if [ -n "${
              if isWrapper
              then serverCfg.launch.root
              else ""
            }" ]; then
              mkdir -p "${workingDir}"
            fi
            ${pkgs.coreutils}/bin/cp -rfT "${declarativeRoot}/." "${serverDataDir}"

            chown -R "${serverCfg.user}:${serverCfg.group}" "${serverDataDir}"
          '';
        in
          nameValuePair "mcserver-${name}" {
            enable = serverCfg.enable;
            description = "Minecraft server instance '${name}'";
            after = ["network.target"];
            wantedBy = ["multi-user.target"];
            path = requiredPackages;
            serviceConfig = {
              Type = "forking";
              User = serverCfg.user;
              Group = serverCfg.group;
              WorkingDirectory = workingDir;
              ExecStartPre = setupScript;
              ExecStart = "${pkgs.screen}/bin/screen -dmS mcserver-${name} ${startCmd}";
              ExecStop = "${pkgs.screen}/bin/screen -S mcserver-${name} -X stuff '${stopCmd}\n'";
              Restart = "always";
              RestartSec = 10;
            };
          }
      )
      cfg.servers;

    environment.systemPackages = [pkgs.screen];
  };
}
