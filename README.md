# NixOS Minecraft Crossplay Module

This repository contains a Nix Flake that exports a NixOS module designed for deploying a high-performance Java Edition Minecraft server with native Bedrock Edition compatibility. The implementation leverages the Paper server software alongside Geyser and Floodgate to provide a seamless cross-platform experience across multiple hardware architectures.

---

## Overview

The configuration is built upon the nix-minecraft community flake which provides the underlying server management framework. This module extends that functionality by declaratively managing the installation and configuration of the Geyser-Spigot and Floodgate-Spigot plugins. It automates the provisioning of network ports for both protocols and handles the generation of the necessary translation layers for Bedrock clients.

The architecture functions by hosting a standard Java Edition server on the default port while simultaneously running a translation proxy. Bedrock clients connect via the User Datagram Protocol on port 19132, where Geyser translates Bedrock packets into Java-compatible packets. Floodgate facilitates this by handling authentication without requiring Bedrock users to possess a separate Java Edition license.

---

## Deployment Profiles

This module includes pre-defined profiles for common hardware architectures. Users can target their specific environment by referencing the appropriate profile during the deployment process.

**x86_64-linux Profile**
This profile is intended for standard Intel or AMD based servers and virtual machines. It is configured to utilize 4GB of system memory by default and uses the G1 Garbage Collector for improved performance.

**aarch64-linux Profile**
This profile is optimized for ARM-based hardware such as Raspberry Pi single-board computers or Oracle Cloud ARM instances. It includes logic to manage memory constraints effectively while maintaining compatibility with the Java translation layer.

---

## Implementation Example

The following example demonstrates how to integrate this module into a standard NixOS flake-based system configuration. The implementation assumes the module is stored in a local directory or referenced via a Git repository.

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    minecraft-crossplay.url = "path:./path-to-this-module";
  };

  outputs = { self, nixpkgs, minecraft-crossplay, ... }: {
    nixosConfigurations.server-instance = nixpkgs.lib.nixosSystem {
      # Select the appropriate system: "x86_64-linux" or "aarch64-linux"
      system = "x86_64-linux";
      modules = [
        minecraft-crossplay.nixosModules.default
        ({ pkgs, ... }: {
          system.stateVersion = "25.11";
          services.my-minecraft.enable = true;
          services.my-minecraft.openFirewall = true;
        })
      ];
    };
  };
}

```

---

## Configuration Requirements

Because this module fetches plugin binaries directly from the GeyserMC build server, users must manually provide the cryptographic hashes for the downloads. Upon the initial execution of a system rebuild, the Nix package manager will identify a hash mismatch for the placeholder values provided in the source code. The user is required to replace these placeholders with the actual SHA-256 hashes provided in the error output to ensure the integrity of the plugin binaries.

The module also implements a declarative configuration for the Geyser plugin. This ensures that the authentication type is correctly set to use Floodgate by default and that the Bedrock listener is properly bound to the appropriate network interfaces. Modifications to these settings should be made within the Nix module logic to maintain the declarative nature of the deployment.

---

## License Information

Copyright 2026 Asher LeRoy

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
