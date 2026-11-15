{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.magpie;
  stateDir = "/var/lib/${cfg.stateDirectoryName}";
  # magpie reads XDG and HOME. It has no data-root flag, so the one
  # StateDirectory is split into the directories it looks up.
  runtimeEnvironment =
    {
      XDG_CONFIG_HOME = "${stateDir}/config";
      XDG_CACHE_HOME = "${stateDir}/cache";
      XDG_DATA_HOME = "${stateDir}/data";
      XDG_STATE_HOME = "${stateDir}/state";
      HOME = "${stateDir}/home";
      BUN_INSTALL_CACHE_DIR = "${stateDir}/cache/bun";
      MAGPIE_ADDR = cfg.listen;
      # agy has no Secret Service here. This selects its file token store
      # below HOME, at .gemini/antigravity-cli/antigravity-oauth-token.
      container = "magpie";
    }
    // lib.optionalAttrs (cfg.publicUrl != null) {
      MAGPIE_PUBLIC_URL = cfg.publicUrl;
    }
    // lib.optionalAttrs cfg.bun.enable {
      MAGPIE_BUN = lib.getExe cfg.bun.package;
    }
    // lib.optionalAttrs (cfg.agy.package != null) {
      AGY_PATH = lib.getExe cfg.agy.package;
    }
    // cfg.environment;

  command =
    if cfg.web.enable
    then [
      "web"
      "--addr"
      cfg.web.listen
      "--no-open"
    ]
    else ["serve"];
in {
  options.services.magpie = {
    enable = lib.mkEnableOption "magpie, a local model gateway";

    package = lib.mkPackageOption pkgs "magpie" {};

    stateDirectoryName = lib.mkOption {
      type = lib.types.str;
      default = "magpie";
      description = ''
        Directory name below {file}`/var/lib` for magpie's configuration,
        plugins, Bun cache, state and home.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "magpie";
      description = ''
        User the service runs as. A static user is required: magpie and agy
        keep files in this user's home across restarts, which a dynamic user
        does not.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "magpie";
      description = "Group the service runs as.";
    };

    listen = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:3425";
      example = "0.0.0.0:3425";
      description = ''
        Address passed as {env}`MAGPIE_ADDR`. An address other than loopback
        makes magpie require an enabled gateway key for remote requests.
      '';
    };

    publicUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://magpie.example.com";
      description = ''
        Address other machines use to reach the gateway, passed as
        {env}`MAGPIE_PUBLIC_URL`. Null leaves it unset.
      '';
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {
        MAGPIE_ALLOW_IPS = "10.0.0.0/8";
        AGY_BRIDGE_MAX_PROCS = "16";
      };
      description = ''
        Extra environment variables. These override the module's own
        variables. Put secrets in {option}`environmentFiles` instead.
      '';
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      description = ''
        Files of extra environment variables, loaded by systemd. Use these
        for secrets such as {env}`MAGPIE_WEB_KEY`.
      '';
    };

    web = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Serve the browser UI with {command}`magpie web` instead of
          {command}`magpie serve`.
        '';
      };

      listen = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:3430";
        example = "0.0.0.0:3430";
        description = "Address passed to {command}`magpie web --addr`.";
      };
    };

    bun = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Put Bun on the service PATH and set {env}`MAGPIE_BUN`. Magpie uses
          it to install and run OpenCode-style plugins. Disable to let magpie
          download Bun into its cache instead.
        '';
      };

      package = lib.mkPackageOption pkgs "bun" {};
    };

    agy.package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        Antigravity CLI package. When set, its executable is passed as
        {env}`AGY_PATH` for the agy-cli plugin. Installing that plugin
        (`magpie plugin add @magpie-community/opencode-agy-cli-auth`) is left
        to the operator; its files live under the state directory.

        The service sets {env}`container` so agy stores its Google sign-in in
        {file}`$HOME/.gemini/antigravity-cli/antigravity-oauth-token` instead
        of the Secret Service keyring. Sign in once as the service user with
        `agy acp --login`. The plugin reads that file on later runs.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !lib.hasInfix " " cfg.listen;
        message = "services.magpie.listen must be host:port without spaces.";
      }
      {
        assertion = !cfg.web.enable || !lib.hasInfix " " cfg.web.listen;
        message = "services.magpie.web.listen must be host:port without spaces.";
      }
    ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = "${stateDir}/home";
    };
    users.groups.${cfg.group} = {};

    systemd.tmpfiles.rules = map (dir: "d ${dir} 0700 ${cfg.user} ${cfg.group} - -") [
      stateDir
      "${stateDir}/config"
      "${stateDir}/cache"
      "${stateDir}/cache/bun"
      "${stateDir}/data"
      "${stateDir}/state"
      "${stateDir}/home"
    ];

    systemd.services.magpie = {
      description = "magpie model gateway";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      environment = runtimeEnvironment;
      path = lib.optionals cfg.bun.enable [cfg.bun.package];
      serviceConfig = {
        ExecStart = lib.escapeShellArgs ([(lib.getExe cfg.package)] ++ command);
        EnvironmentFile = cfg.environmentFiles;
        WorkingDirectory = stateDir;
        StateDirectory = cfg.stateDirectoryName;
        StateDirectoryMode = "0700";
        User = cfg.user;
        Group = cfg.group;
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = "3s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateDevices = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictSUIDSGID = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
      };
    };
  };
}
