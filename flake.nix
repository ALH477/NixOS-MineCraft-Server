{
  description = "A portable Minecraft Server Module with Geyser + Floodgate support";

  inputs = {
    # Using unstable to ensure access to the absolute latest JDKs and packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    
    # --- 1. THE MODULE OUTPUT ---
    nixosModules.default = { config, lib, pkgs, ... }: 
      let
        cfg = config.services.my-minecraft;
      in {
        options.services.my-minecraft = {
          enable = lib.mkEnableOption "Minecraft Paper Server with Crossplay";
          openFirewall = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to open TCP 25565 (Java) and UDP 19132 (Bedrock).";
          };
        };

        config = lib.mkIf cfg.enable {
          # Import the community module
          imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];
          
          # Overlay to access Paper servers
          nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];
          
          # Required for Minecraft EULA
          nixpkgs.config.allowUnfree = true;

          # Open ports if requested
          networking.firewall = lib.mkIf cfg.openFirewall {
            allowedTCPPorts = [ 25565 ];
            allowedUDPPorts = [ 19132 ];
          };

          services.minecraft-servers = {
            enable = true;
            eula = true;

            servers.survival = {
              enable = true;
              
              # IMPORTANT: Check available versions if this fails:
              # 'nix search github:Infinidoge/nix-minecraft paper'
              package = pkgs.paperServers.paper-1_21_4; 
              
              jvmOpts = "-Xms4G -Xmx4G -XX:+UseG1GC";

              serverProperties = {
                server-port = 25565;
                motd = "NixOS Crossplay Module";
                difficulty = "normal";
                white-list = false; 
                online-mode = true; 
              };

              # Declarative Plugin Installation
              # NOTE: These URLs point to "latest". If the plugin updates upstream,
              # the hash will change, and Nix will error. You must update the hash manually.
              symlinks = {
                "plugins/Geyser-Spigot.jar" = pkgs.fetchurl {
                  url = "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot";
                  sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # REPLACE THIS ON FIRST RUN
                };
                "plugins/Floodgate-Spigot.jar" = pkgs.fetchurl {
                  url = "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot";
                  sha256 = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="; # REPLACE THIS ON FIRST RUN
                };
                
                # Declarative Geyser Config
                # We force Geyser to listen on UDP and auth via Floodgate
                "plugins/Geyser-Spigot/config.yml" = pkgs.writeText "config.yml" ''
                  bedrock:
                    address: 0.0.0.0
                    port: 19132
                  remote:
                    address: auto
                    port: 25565
                    auth-type: floodgate
                  floodgate-key-file: ../Floodgate-Spigot/key.pem
                '';
              };
            };
          };
        };
      };

    # --- 2. EXAMPLE SYSTEM CONFIGURATION ---
    nixosConfigurations.minecraft-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        # Import the module defined above
        self.nixosModules.default

        ({ ... }: {
          # UPDATED: Set to 25.11 as requested
          system.stateVersion = "25.11"; 
          
          # Enable the module
          services.my-minecraft.enable = true;
        })
      ];
    };
  };
}
