# nixcraft

A nix module that let you manage the minecraft server declaratively, with extra customizability

Import the `./objects/server.nix` to your `imports`, and add configuration as import inputs.

**Make sure to use `import` instead of `pkgs.callPackage`, or infinite recursion will happen.**

> will try to migrate to flake-based config but I don't know how right now

## Data structures reference

#### File: an attribute set that defines a file:

```nix
leaves_1_20_1 = {
    # the remote url of the file, ignored if `path` is specified
    url = "https://github.com/LeavesMC/Leaves/releases/download/1.20.1-847357b/leaves-1.20.1.jar";
    # name of the file, required
    name = "leaves";
    # suffix of the file, optional since most cases it can be inferenced
    # but if filled, the file will be named as ${name}${suffix}
    # preceding "." will be filled if there is no preceding "."
    # in this case if this is not specified the inference result will be `jar`
    suffix = "jar";
    # hash of remote file, required if `url` is specified
    wrapper = "sha256-cfH5beGJM+ZIzPLQTu0Z8aJAjp/qlH7AcONe85zTQiQ=";
    # path of the file relative to the root in the context of the server
    # root is inferenced from the other configuration options
    # in some cases this is optional
    dir = "...";
    # path of the local file, optional if `url` is given
    path = "...";
}
```

#### Wrapper: an attribute set that defines a server wrapper:

```nix
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
in
mcdr_wrapper = {
    # where the server kernel will be copied to, required
    root = "server";
    # package that provides the server exec, required
    # this can be a package, a list of package, or a list of mixed of package and file objects
    package = mcdr;
    # plugins, a list of file objects, each one specifies a plugin
    # in this case the dir is relative to the configured server root in the server config (will introduce later)
    # required, if no plugin just fill in a empty list
    # see ./example/mcdr/plugins.nix for example
    plugins = import ./example/mcdr/plugins.nix;
    # plugins, a list of file objects, each one specifies a plugin
    # in this case the dir is relative to the configured server root in the server config (will introduce later)
    # required, if no configs just fill in a empty list
    # see ./example/mcdr/configs.nix for example
    confs = (import ./example/mcdr//configs.nix);
    # command executed in the server root directory to start the server
    start_cmd = "${mcdr}/bin/mcdreforged start";
    # command executed in the server root directory to start the server
    # note this will be send into the stdin of the server screen session as it is
    stop_cmd = "!!MCDR server stop";
};
```

## Adding a server

One import of `./objects/server.nix` is one server. A example of a server is this:

If any of the required list is not applicable to the server (like the `mod_list` section in the configuration since leaves is a plugin server kernel), just provide a empty list

```nix
import ./objects/server.nix {
    # required, since we are using `import` instead of pkgs.callPackage
    inherit pkgs lib;
    # package providing the `java` command, required
    jdk = pkgs.jdk;
    # server name, required
    name = "tita-creative";
    # server kernel, a file object, with root being /etc/srv/${name}/, required
    kernel = {
    url =
        "https://github.com/LeavesMC/Leaves/releases/download/1.20.1-847357b/leaves-1.20.1.jar";
    name = "leaves";
    hash = "sha256-cfH5beGJM+ZIzPLQTu0Z8aJAjp/qlH7AcONe85zTQiQ=";
    };

    # a wrapper object, describes a server wrapper.
    # If you don't want to use a wrapper, replace this with the server start command
    # mcdr_wrapper is defined in the Data structures reference section
    # inside this section, the root is inferenced to be /etc/srv/${name}/
    wrapper = mcdr_wrapper;
    # server stop command
    # will be ignored if wrapper is specified
    # note this will be send into the stdin of the server screen session as it is
    stop_cmd = "";
    # mod directory, relative to the server directory.
    mod_dir = "mods";
    # a list of file object, describes the list of mod you want to install
    # inside this list, if the wrapper is specified, root will be
    # /etc/srv/${name}/${wrapper.root}/${mod_dir}/
    # otherwise it will be /etc/srv/${name}/${mod_dir}/
    mod_list = [ ];
    # mod directory, relative to the server directory.
    plugin_dir = "plugins";
    # a list of file object, describes the list of plugins you want to install
    # inside this list
    # If the wrapper is specified, root will be:
    # /etc/srv/${name}/${wrapper.root}/${plugin_dir}/
    # otherwise it will be /etc/srv/${name}/${plugin_dir}/
    plugin_list = (import ./configs/tita/plugins.nix);
    # a list of file object, describes the list of configuration files
    # inside this list, if the wrapper is specified, root will be /etc/srv/${name}/${wrapper.root}/
    # otherwise it will be /etc/srv/${name}/
    conf_list = (import ./configs/tita/configs.nix);
}
```

## Server management

Each server will be started as a screen session, named `mcserver-${name}`. And each server file will be inside directory `/etc/srv/${name}/`. Each screen session is started by a systemd service named `mcserver-${name}.service`.

To restart the server, just reload the systemd service.

Not sure whether I will make server managment panel support, probably not.

## Limitation

Currently no datapack support.

Currently can only specify server location to be the below the `/etc/srv`.

Hashes needs to be added manually for each file.

Need to have the url pointing directly to the destination file (i.e. `https://api.leavesmc.org/v2/projects/leaves/versions/1.20.1/builds/102/downloads/application` doesn't work)
