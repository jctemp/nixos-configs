# NixOS Configuration Implementation Plan

## Phase 1: Foundation
- Set up flake.nix with all inputs (nixpkgs, home-manager, disko, impermanence, nixsops, nix-facter)
- Implement `lib/mkSystem.nix` and `lib/mkHome.nix` functions
- Create module option structure (`mySystem.*` and `myHome.*`)
- Set up basic testing framework

## Phase 2: Core System
- **modules/nixos/core/**
  - `boot.nix` - Boot loader and kernel config
  - `nixos.nix` - Nix daemon settings
  - `networking.nix` - NetworkManager and hostname
  - `users.nix` - User account management
  - `security.nix` - Basic hardening
  - `locale.nix` - Timezone and keyboard

## Phase 3: Hardware & Storage
- **modules/nixos/hardware/**
  - `facter.nix` - Hardware detection integration
  - `nvidia.nix` - GPU support
  - `bluetooth.nix` - Bluetooth stack
- **modules/nixos/storage/**
  - `boot.nix`, `root.nix`, `data.nix`, `swap.nix`
  - Integrate disko and impermanence

## Phase 4: Services
- **modules/nixos/services/**
  - `audio.nix` - PipeWire configuration
  - `printing.nix` - CUPS setup
  - `qemu.nix` - Virtualization
  - `containers.nix` - Docker/Podman

## Phase 5: System Profiles
- **modules/nixos/profiles/**
  - `minimal.nix` - Server/headless config
  - `optimised.nix` - Performance tuning
  - `full.nix` - Complete desktop

## Phase 6: Home Foundation
- **modules/home/core/**
  - `fonts.nix` - Font management
  - `theme.nix` - GTK/Qt theming
  - `xdg.nix` - XDG directories

## Phase 7: Applications
- **modules/home/applications/**
  - `helix.nix` - Editor with LSP
  - `ghostty.nix` - Terminal emulator
  - `starship.nix` - Shell prompt
  - `zellij.nix` - Terminal multiplexer

## Phase 8: Desktop Environment
- **modules/home/desktop/**
  - `gnome.nix` - GNOME configuration
  - `media.nix` - Media applications

## Phase 9: Home Profiles
- **modules/home/profiles/**
  - `development.nix` - Developer tools
  - `full.nix` - Complete desktop experience

## Phase 10: Host Configurations
- **hosts/** - becon, carriage, tower
  - Hardware-specific configs
  - nix-facter integration
  - Disk layouts with disko

## Phase 11: Home Configurations
- **homes/** - remote, zen
  - User-specific settings
  - Workflow configurations

## Phase 12: Secrets & Security
- **secrets/**
  - nixsops integration
  - Age key management
  - Security hardening

## Phase 13: Testing
- **tests/**
  - Unit tests for modules
  - Integration tests for profiles
  - Build verification
  - VM-based testing
