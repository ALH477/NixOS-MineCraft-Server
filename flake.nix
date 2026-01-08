{
  description = "A portable Minecraft Server Module with Geyser + Floodgate support";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    
    # --- 1. THE SHARED NIXOS MODULE ---
    # Use this for full NixOS server deployments (VMs, bare metal)
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
          imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];
          nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];
          nixpkgs.config.allowUnfree = true;

          networking.firewall = lib.mkIf cfg.openFirewall {
            allowedTCPPorts = [ 25565 ];
            allowedUDPPorts = [ 19132 ];
          };

          services.minecraft-servers = {
            enable = true;
            eula = true;
            servers.survival = {
              enable = true;
              package = pkgs.paperServers.paper-1_21_4; 
              jvmOpts = "-Xms4G -Xmx4G -XX:+UseG1GC";
              serverProperties = {
                server-port = 25565;
                motd = "NixOS Crossplay Module";
                difficulty = "normal";
                white-list = false; 
                online-mode = true; 
              };
              symlinks = {
                # NOTE: Update hashes on first run failure
                "plugins/Geyser-Spigot.jar" = pkgs.fetchurl {
                  url = "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot";
                  sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; 
                };
                "plugins/Floodgate-Spigot.jar" = pkgs.fetchurl {
                  url = "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot";
                  sha256 = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
                };
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

    # --- 2. VM/SYSTEM PROFILES ---
    # Deploy directly with `nix run .#minecraft-server-x86`
    
    nixosConfigurations.minecraft-server-x86 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        self.nixosModules.default
        ({ ... }: { system.stateVersion = "25.11"; services.my-minecraft.enable = true; })
      ];
    };

    nixosConfigurations.minecraft-server-arm = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        self.nixosModules.default
        ({ ... }: { 
          system.stateVersion = "25.11"; 
          services.my-minecraft.enable = true;
          # Lower memory for ARM dev boards (like RPi)
          services.minecraft-servers.servers.survival.jvmOpts = 
            nixpkgs.lib.mkForce "-Xms2G -Xmx2G -XX:+UseG1GC";
        })
      ];
    };

    # --- 3. DOCKER CONTAINERS (alh477) ---
    # Build with: nix build .#packages.x86_64-linux.dockerImage
    
    packages = let
      mkDocker = system: 
        let 
          pkgs = import nixpkgs { 
            inherit system; 
            config.allowUnfree = true;
            overlays = [ inputs.nix-minecraft.overlay ];
          };
          
          # Components
          serverPackage = pkgs.paperServers.paper-1_21_4;
          jre = pkgs.jdk21; 
          
          # Plugin Assets
          geyserJar = pkgs.fetchurl {
            url = "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot";
            sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; 
          };
          floodgateJar = pkgs.fetchurl {
            url = "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot";
            sha256 = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
          };
          geyserConfig = pkgs.writeText "config.yml" ''
            bedrock:
              address: 0.0.0.0
              port: 19132
            remote:
              address: auto
              port: 25565
              auth-type: floodgate
            floodgate-key-file: ../Floodgate-Spigot/key.pem
          '';

          # Smart Startup Script
          startScript = pkgs.writeScriptBin "start-server" ''
            #!${pkgs.runtimeShell}
            set -e

            echo ">>> Initializing Server Environment..."
            mkdir -p plugins/Geyser-Spigot plugins/Floodgate-Spigot

            echo ">>> Linking Plugins..."
            ln -sf ${geyserJar} plugins/Geyser-Spigot.jar
            ln -sf ${floodgateJar} plugins/Floodgate-Spigot.jar
            
            # Copy config (needs to be writable? usually no, but we copy to be safe)
            cp -f ${geyserConfig} plugins/Geyser-Spigot/config.yml

            # KEY GENERATION LOGIC
            KEY_FILE="plugins/Floodgate-Spigot/key.pem"
            if [ ! -f "$KEY_FILE" ]; then
              echo ">>> Floodgate key missing. Initializing Floodgate structure..."
              # Note: Floodgate automatically generates the key on first run if the folder exists.
              # We rely on the plugin itself to do this securely rather than doing it in shell.
            else
              echo ">>> Floodgate key found."
            fi
            
            echo ">>> Accepting EULA..."
            echo "eula=true" > eula.txt
            
            echo ">>> Starting Paper Server..."
            exec ${jre}/bin/java -Xms4G -Xmx4G -jar ${serverPackage}/lib/minecraft/server.jar nogui
          '';

        in pkgs.dockerTools.buildLayeredImage {
          name = "alh477/minecraft-server";
          tag = "latest";
          created = "now";
          contents = [ startScript jre serverPackage pkgs.bashInteractive pkgs.coreutils pkgs.openssl ];
          config = {
            Cmd = [ "${startScript}/bin/start-server" ];
            ExposedPorts = {
              "25565/tcp" = {};
              "19132/udp" = {};
            };
            WorkingDir = "/data";
            Volumes = { "/data" = {}; };
          };
        };
    in {
      x86_64-linux.dockerImage = mkDocker "x86_64-linux";
      aarch64-linux.dockerImage = mkDocker "aarch64-linux";
    };
  };
}
