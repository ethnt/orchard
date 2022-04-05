{ config, pkgs, resources, nodes, ... }: {
  deployment = { targetHost = "192.168.1.44"; };

  imports = [ ../../profiles/virtualized ./hardware-configuration.nix ];

  sops = {
    secrets = {
      nebula_host_key = { sopsFile = ./secrets.yaml; };
      nebula_host_cert = { sopsFile = ./secrets.yaml; };
    };
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver ];
  };

  networking.privateIPv4 = "192.168.1.44";


  environment.systemPackages = with pkgs; [ handbrake ];

  # TODO: Make other systemd services (sonarr, etc) require mount to finish first
  fileSystems."/mnt/omnibus" = {
    device = "192.168.1.12:/mnt/omnibus/htpc";
    fsType = "nfs";
    options = [
      "noauto"
      "x-systemd.automount"
      "x-systemd.requires=network-online.target"
      "x-systemd.device-timeout=10"
    ];
  };

  users.groups.htpc = {
    gid = 1042;
    members = [ "nzbget" "sonarr" "radarr" "plex" "sabnzbd" ];
  };

  users.users.htpc = {
    uid = 1042;
    isSystemUser = true;
    isNormalUser = false;
    group = config.users.groups.htpc.name;
  };

  orchard = {
    services = {
      nebula = {
        enable = true;
        network = {
          lighthouses = [ "10.10.10.1" ];
          staticHostMap = {
            "10.10.10.1" =
              [ "${nodes.gateway.config.deployment.targetHost}:4242" ];
          };
        };
        host = {
          addr = "10.10.10.2";
          keyPath = config.sops.secrets.nebula_host_key.path;
          certPath = config.sops.secrets.nebula_host_cert.path;
        };
      };

      docker.enable = true;

      sonarr = {
        enable = true;
        openFirewall = true;
        group = "htpc";
      };

      radarr = {
        enable = true;
        openFirewall = true;
        group = "htpc";
      };

      plex = {
        enable = true;
        openFirewall = true;
        group = "htpc";
      };

      nzbget = {
        enable = true;
        openFirewall = true;
        group = "htpc";
      };

      prowlarr = {
        enable = true;
        openFirewall = true;
      };

      overseerr = {
        enable = true;
        openFirewall = true;
      };

      tautulli = {
        enable = true;
        openFirewall = true;
      };

      sabnzbd = {
        enable = true;
        openFirewall = true;
        group = "htpc";
      };

      promtail = {
        enable = true;
        host = "htpc";
        lokiServerConfiguration = {
          host = nodes.monitor.config.orchard.services.loki.host;
          port = nodes.monitor.config.orchard.services.loki.port;
        };
      };

      prometheus-node-exporter = {
        enable = true;
        host = "monitor.orchard.computer";
        openFirewall = true;
      };

      restic = {
        enable = true;
        backupName = "htpc";
        paths = [ "/var/lib" ];
        passwordFile = config.sops.secrets.backup_password.path;
        s3 = {
          bucketName = resources.s3Buckets.htpc-backups-bucket.name;
          credentialsFile = config.sops.secrets.aws_credentials.path;
        };
      };
    };
  };
}
