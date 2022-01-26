{ config, pkgs, resources, nodes, ... }: {
  deployment = { targetHost = "192.168.1.198"; };

  imports = [ ./hardware-configuration.nix ];

  networking.publicIPv4 = "192.168.1.219";

  sops.secrets = {
    # nebula_ca_cert = { sopsFile = ../secrets.yaml; };
    # nebula_host_key = { sopsFile = ./secrets.yaml; };
    # nebula_host_cert = { sopsFile = ./secrets.yaml; };
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  system.stateVersion = "21.11";

  services.qemuGuest.enable = true;

  orchard = {
    services = {
      # nebula = {
      #   enable = true;
      #   caCert = config.sops.secrets.nebula_ca_cert.path;
      #   hostKey = config.sops.secrets.nebula_host_key.path;
      #   hostCert = config.sops.secrets.nebula_host_cert.path;
      #   staticHostMap = {
      #     "10.11.12.1" =
      #       [ "${nodes.bastion.config.networking.publicIPv4}:4242" ];
      #   };
      #   lighthouses = [ "10.11.12.1" ];
      # };

      prometheus-exporter = {
        enable = true;
        host = "builder";
        node = {
          enable = true;
          openFirewall = true;
        };
      };

      promtail = {
        enable = true;
        host = "builder";
        lokiServerConfiguration = {
          host = nodes.monitor.config.networking.privateIPv4;
          port = nodes.monitor.config.orchard.services.loki.port;
        };
      };

      remote-builder = {
        enable = true;
        emulatedSystems = [ "aarch64-linux" ];
        buildUserKeyFile = ./keys/builder.pub;
      };
    };
  };
}
