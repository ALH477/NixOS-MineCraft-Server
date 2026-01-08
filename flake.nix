{
  description = "A portable Minecraft Server Module with Geyser + Floodgate support";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    
    # --- 1. THE SHARED MODULE (Architecture Agnostic) ---
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
              
              # Paper 1.21.4 (Java is cross-platform, so this works on ARM too)
              package = pkgs.paperServers.paper-1_21_4; 
              
              # JVM flags optimized for performance
              jvmOpts = "-Xms4G -Xmx4G -XX:+UseG1GC";

              serverProperties = {
                server-port = 25565;
                motd = "NixOS Crossplay Module";
                difficulty = "normal";
                white-list = false; 
                online-mode = true; 
              };

              # Declarative Plugin Installation
              # NOTE: Run once, capture the hash error, update these values.
              symlinks = {
                "plugins/Geyser-Spigot.jar" = pkgs.fetchurl {
                  url = "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot";
                  sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; 
                };
                "plugins/Floodgate-Spigot.jar" = pkgs.fetchurl {
                  url = "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot";
                  sha256 = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
                };
                
                # Declarative Geyser Config
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

    # --- 2. PROFILES (System Configurations) ---

    # Profile 1: Standard x86_64 (Intel/AMD)
    # Run: nix run .#minecraft-server-x86
    nixosConfigurations.minecraft-server-x86 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        self.nixosModules.default
        ({ ... }: {
          system.stateVersion = "25.11";
          services.my-minecraft.enable = true;
        })
      ];
    };

    # Profile 2: ARM64 (Raspberry Pi 4/5, Oracle Cloud ARM, Apple Silicon VMs)
    # Run: nix run .#minecraft-server-arm
    nixosConfigurations.minecraft-server-arm = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        self.nixosModules.default
        ({ ... }: {
          system.stateVersion = "25.11";
          services.my-minecraft.enable = true;
          
          # Optional: Adjust memory if running on a constrained Pi
          services.minecraft-servers.servers.survival.jvmOpts = 
            nixpkgs.lib.mkForce "-Xms2G -Xmx2G -XX:+UseG1GC";
        })
      ];
    };
  };
}
