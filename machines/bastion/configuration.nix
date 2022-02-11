{ config, pkgs, resources, nodes, ... }: {
  deployment = { targetHost = "192.168.1.100"; };

  networking.publicIPv4 = "74.65.199.203";
  networking.privateIPv4 = "10.10.10.1";

  imports = [ ./hardware-configuration.nix ];

  sops.secrets = {
    nebula_host_key = { sopsFile = ./secrets.yaml; };
    nebula_host_cert = { sopsFile = ./secrets.yaml; };
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  services.qemuGuest.enable = true;

  services.nebula.networks.orchard = {
    enable = true;
    isLighthouse = true;
    ca = config.sops.secrets.nebula_ca_cert.path;
    key = config.sops.secrets.nebula_host_key.path;
    cert = config.sops.secrets.nebula_host_cert.path;
    firewall = {
      inbound = [{
        host = "any";
        port = "any";
        proto = "any";
      }];
      outbound = [{
        host = "any";
        port = "any";
        proto = "any";
      }];
    };
  };

  services.caddy = {
    enable = true;
    email = "ethan.turkeltaub+orchard@hey.com";
    config = ''
      arbor.orchard.computer {
        encode gzip
        log
        reverse_proxy * 192.168.1.93:8006
      }

      satan.orchard.computer {
        encode gzip
        log
        reverse_proxy * 192.168.1.1:81
      }

      sonarr.orchard.computer {
        encode gzip
        log
        reverse_proxy * ${nodes.htpc.config.networking.privateIPv4}:${
          toString nodes.htpc.config.orchard.services.sonarr.port
        } {
        }
      }

      radarr.orchard.computer {
        encode gzip
        log
        reverse_proxy * ${nodes.htpc.config.networking.privateIPv4}:${
          toString nodes.htpc.config.orchard.services.radarr.port
        } {
        }
      }

      plex.orchard.computer {
        encode gzip
        log
        reverse_proxy * ${nodes.htpc.config.networking.privateIPv4}:${
          toString nodes.htpc.config.orchard.services.plex.port
        } {
        }
      }

      nzbget.orchard.computer {
        encode gzip
        log
        reverse_proxy * ${nodes.htpc.config.networking.privateIPv4}:${
          toString nodes.htpc.config.orchard.services.nzbget.port
        } {
        }
      }

      grafana.orchard.computer {
        encode gzip
        log
        reverse_proxy * ${nodes.monitor.config.networking.privateIPv4}:${
          toString nodes.monitor.config.orchard.services.grafana.port
        } {
        }
      }

      tautulli.orchard.computer {
        encode gzip
        log
        reverse_proxy * ${nodes.htpc.config.networking.privateIPv4}:${
          toString nodes.monitor.config.orchard.services.tautulli.port
        } {
        }
      }

      omnibus.orchard.computer {
        encode gzip
        log
        reverse_proxy http://192.168.1.12
      }
    '';
  };

  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
    allowedUDPPorts = [ 80 443 4242 ];
  };

  orchard = {
    services = {
      docker.enable = true;

      consul = {
        enable = true;
        web = {
          enable = true;
          openFirewall = true;
        };
      };

      nginx = {
        enable = false;
        acme.email = "ethan.turkeltaub+orchard@hey.com";

        virtualHosts = {
          "arbor.orchard.computer" = {
            http2 = true;

            addSSL = true;
            enableACME = true;

            locations."/" = { proxyPass = "https://192.168.1.93:8006"; };
          };

          "plex.orchard.computer" = {
            http2 = true;

            addSSL = true;
            enableACME = true;

            extraConfig = ''
              send_timeout 100m;
              ssl_stapling on;
              ssl_stapling_verify on;
              ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
              ssl_prefer_server_ciphers on;
              ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:ECDHE-RSA-DES-CBC3-SHA:ECDHE-ECDSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header Host $server_addr;
              proxy_set_header Referer $server_addr;
              proxy_set_header Origin $server_addr;
              gzip on;
              gzip_vary on;
              gzip_min_length 1000;
              gzip_proxied any;
              gzip_types text/plain text/css text/xml application/xml text/javascript application/x-javascript image/svg+xml;
              gzip_disable "MSIE [1-6]\.";
              client_max_body_size 100M;
              proxy_set_header X-Plex-Client-Identifier $http_x_plex_client_identifier;
              proxy_set_header X-Plex-Device $http_x_plex_device;
              proxy_set_header X-Plex-Device-Name $http_x_plex_device_name;
              proxy_set_header X-Plex-Platform $http_x_plex_platform;
              proxy_set_header X-Plex-Platform-Version $http_x_plex_platform_version;
              proxy_set_header X-Plex-Product $http_x_plex_product;
              proxy_set_header X-Plex-Token $http_x_plex_token;
              proxy_set_header X-Plex-Version $http_x_plex_version;
              proxy_set_header X-Plex-Nocache $http_x_plex_nocache;
              proxy_set_header X-Plex-Provides $http_x_plex_provides;
              proxy_set_header X-Plex-Device-Vendor $http_x_plex_device_vendor;
              proxy_set_header X-Plex-Model $http_x_plex_model;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
              proxy_http_version 1.1;
              proxy_redirect off;
              proxy_buffering off;
            '';

            locations."/" = {
              proxyPass = "http://${nodes.htpc.config.networking.privateIPv4}:${
                  toString nodes.htpc.config.orchard.services.plex.port
                }";
            };
          };

          "sonarr.orchard.computer" = {
            http2 = true;

            addSSL = true;
            enableACME = true;

            locations."/" = {
              proxyPass = "http://${nodes.htpc.config.networking.privateIPv4}:${
                  toString nodes.htpc.config.orchard.services.sonarr.port
                }";
            };
          };

          "radarr.orchard.computer" = {
            http2 = true;

            addSSL = true;
            enableACME = true;

            locations."/" = {
              proxyPass = "http://${nodes.htpc.config.networking.privateIPv4}:${
                  toString nodes.htpc.config.orchard.services.radarr.port
                }";
            };
          };

          "tautulli.orchard.computer" = {
            http2 = true;

            addSSL = true;
            enableACME = true;

            locations."/" = {
              proxyPass = "http://${nodes.htpc.config.networking.privateIPv4}:${
                  toString nodes.htpc.config.orchard.services.tautulli.port
                }";
            };
          };
        };
      };

      # nebula = {
      #   enable = true;
      #   isLighthouse = true;
      #   caCert = config.sops.secrets.nebula_ca_cert.path;
      #   hostKey = config.sops.secrets.nebula_host_key.path;
      #   hostCert = config.sops.secrets.nebula_host_cert.path;
      # };

      prometheus-exporter = {
        enable = false;
        host = "bastion";
        node = {
          enable = true;
          openFirewall = true;
        };
      };

      promtail = {
        enable = false;
        host = "bastion";
        lokiServerConfiguration = {
          host = nodes.monitor.config.networking.privateIPv4;
          port = nodes.monitor.config.orchard.services.loki.port;
        };
      };

      # nginx = {
      #   enable = true;
      #   acme.email = "ethan.turkeltaub+orchard-computer@hey.com";
      # };
    };
  };
}
