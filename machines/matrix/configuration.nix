{ config, lib, pkgs, resources, nodes, ... }:
let aws = import ../../config/aws.nix;
in {
  deployment = {
    targetEnv = "ec2";
    ec2 = {
      inherit (aws) region;

      instanceType = "t3.medium";
      keyPair = resources.ec2KeyPairs.deployment-key;
      securityGroups = [ resources.ec2SecurityGroups.matrix-security-group ];
      ebsBoot = true;
      ebsInitialRootDiskSize = 64;
      elasticIPv4 = resources.elasticIPs.matrix-elastic-ip;
    };
  };

  sops = {
    secrets = {
      nebula_host_key = { sopsFile = ./secrets.yaml; };
      nebula_host_cert = { sopsFile = ./secrets.yaml; };
    };
  };

  orchard = {
    services = {
      nebula = {
        enable = true;
        network = {
          lighthouses = [ "10.10.10.1" ];
          staticHostMap = {
            "10.10.10.1" =
              [ "${nodes.gateway.config.networking.publicIPv4}:4242" ];
            "10.10.10.2" =
              [ "${nodes.gateway.config.networking.publicIPv4}:4343" ];
            "10.10.10.3" =
              [ "${nodes.gateway.config.networking.publicIPv4}:4444" ];
          };
        };
        host = {
          addr = "10.10.10.5";
          keyPath = config.sops.secrets.nebula_host_key.path;
          certPath = config.sops.secrets.nebula_host_cert.path;
        };
      };

      remote-builder = {
        enable = true;
        emulatedSystems = [ "aarch64-linux" ];
        buildUserPublicKeyFile = ./remote-builder/builder.pub;
      };

      promtail = {
        enable = true;
        host = "matrix";
        lokiServerConfiguration = {
          host = nodes.monitor.config.orchard.services.loki.host;
          port = nodes.monitor.config.orchard.services.loki.port;
        };
      };

      prometheus-node-exporter = {
        enable = true;
        host = "matrix.orchard.computer";
        openFirewall = true;
      };

      prometheus-nginx-exporter = {
        enable = true;
        scrapeUri = "http://matrix.orchard.computer/stub_status";
        openFirewall = true;
      };

      nginx = {
        enable = true;
        acme.email = "admin@orchard.computer";

        virtualHosts = {
          "matrix.orchard.computer" = {
            locations."/stub_status" = {
              extraConfig = ''
                stub_status;
              '';
            };
          };

          "e10.land" = {
            addSSL = true;
            enableACME = true;

            locations."/" = {
              root = "/var/www/e10.land";
              extraConfig = ''
                autoindex on;
                fancyindex on;
              '';
            };
          };
        };
      };
    };
  };
}