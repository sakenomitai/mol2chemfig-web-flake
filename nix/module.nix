self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.mol2chemfig-web;
  runtimeDir = "/run/mol2chemfig-web";
in
{
  options.services.mol2chemfig-web = {
    enable = lib.mkEnableOption "the mol2chemfig web interface";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "mol2chemfig-web.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "The mol2chemfig-web package to run.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "[::]";
      description = "Address gunicorn listens on. Put IPv6 addresses in brackets.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "TCP port gunicorn listens on.";
    };

    threads = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = ''
        Number of request threads. The app keeps the last converted molecule
        in process memory, so it always runs in a single gunicorn worker.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open {option}`port` in the firewall.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "--access-logfile"
        "-"
      ];
      description = "Extra command line arguments for gunicorn.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.mol2chemfig-web = {
      description = "mol2chemfig web interface";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        # long molfiles are passed to mol2chemfig through a file
        MOL2CHEMFIG_DATA_DIR = runtimeDir;
        # somewhere writable for TeX, should it want to cache anything
        HOME = runtimeDir;
      };

      serviceConfig = {
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe cfg.package)
            "--bind"
            "${cfg.listenAddress}:${toString cfg.port}"
            "--workers"
            "1"
            "--threads"
            (toString cfg.threads)
          ]
          ++ cfg.extraArgs
        );
        Restart = "on-failure";

        DynamicUser = true;
        RuntimeDirectory = "mol2chemfig-web";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";

        # pdflatex runs on code users type into the page, so keep the
        # service away from everything it doesn't need
        CapabilityBoundingSet = "";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        RemoveIPC = true;
        # outbound HTTPS to PubChem needs INET; gunicorn itself needs UNIX
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
