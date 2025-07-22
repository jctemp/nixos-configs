{ pkgs, config, ... }:
{
  # Core development packages
  packages = with pkgs; [
    nixfmt-rfc-style # Nix formatter
    deadnix # Dead code detection
    statix # Linter for Nix
    nix-output-monitor # Better build output
    taplo # TOML

    # Development tools
    git
    age # For nixsops
    ssh-to-age # Convert SSH keys to age

    # Documentation and validation
    nixos-generators # Generate various formats
    nixos-anywhere # Remote deployment

    # VM testing
    qemu # For nixos tests
  ];

  # Development environment variables
  env = {
    NIX_CONFIG = "extra-experimental-features = nix-command flakes";
    SOPS_AGE_KEY_FILE = "${config.env.DEVENV_ROOT}/secrets/age-key.txt";
    NIXPKGS_ALLOW_UNFREE = "1";
  };

  git-hooks = {
    hooks = {
      trim-trailing-whitespace.enable = true;
      end-of-file-fixer.enable = true;
      nixfmt-rfc-style = {
        enable = true;
        excludes = [ "hardware-configuration.nix" ];
      };
      deadnix = {
        enable = true;
        settings = {
          edit = true;
          hidden = false;
        };
      };
      statix = {
        enable = true;
        settings = {
          ignore = [
            "hosts/*/hardware-configuration.nix"
            "hosts/*/facter.json"
          ];
        };
      };
      typos = {
        enable = true;
      };
      ripsecrets = {
        enable = true;
      };
    };
  };

  scripts = {
    build-host = {
      exec = ''
        if [ -z "$1" ]; then
          echo "Usage: build-host <hostname>"
          exit 1
        fi
        echo "Building host: $1"
        nix build .#nixosConfigurations.$1.config.system.build.toplevel "$@"
      '';
      description = "Build a specific host configuration";
    };

    build-home = {
      exec = ''
        if [ -z "$1" ]; then
          echo "Usage: build-home <user@host>"
          exit 1
        fi
        echo "Building home: $1"
        nix build .#homeConfigurations."$1".activationPackage "$@"
      '';
      description = "Build a specific home configuration";
    };

    gen-hardware = {
      exec = ''
        if [ -z "$1" ]; then
          echo "Usage: gen-hardware <hostname>"
          exit 1
        fi
        echo "Generating hardware config for: $1"
        mkdir -p hosts/$1
        nix run github:numtide/nix-facter -- --output hosts/$1/facter.json
      '';
      description = "Generate hardware configuration";
    };

    # Edit secrets
    edit-secrets = {
      exec = ''
        nixsops --config secrets/.sops.yaml edit secrets/secrets.yaml
      '';
      description = "Edit secrets file";
    };

    # Development VM
    vm = {
      exec = ''
        if [ -z "$1" ]; then
          echo "Usage: vm <hostname>"
          exit 1
        fi
        echo "Starting VM for: $1"
        nixos-rebuild build-vm --flake .#$1
        ./result/bin/run-*-vm
      '';
      description = "Build and run a VM for testing";
    };

    # Format all nix files
    fmt = {
      exec = ''
        echo "Formatting all Nix files..."
        find . -name "*.nix" -not -path "./hosts/*/hardware-configuration.nix" -exec nixpkgs-fmt {} \;
      '';
      description = "Format all Nix files";
    };

    # Lint all nix files
    lint = {
      exec = ''
        echo "Linting all Nix files..."
        statix check .
        deadnix --fail .
      '';
      description = "Lint all Nix files";
    };

    # Update all inputs
    update = {
      exec = ''
        echo "Updating all flake inputs..."
        nix flake update
      '';
      description = "Update all flake inputs";
    };

    # # Run unit tests
    # test-unit = {
    #   exec = ''
    #     echo "Running unit tests"
    #     nix-instantiate --eval --strict --arg pkgs 'import <nixpkgs> {}' ./lib/mkHome_test.nix
    #     nix-instantiate --eval --strict --arg pkgs 'import <nixpkgs> {}' ./lib/mkSystem_test.nix
    #     nix-instantiate --eval --strict --arg pkgs 'import <nixpkgs> {}' ./lib/utils_test.nix
    #   '';
    #   description = "Run test for the project";
    # };
  };

  services = {
    nginx = {
      enable = false; # Enable if you want local docs
      httpConfig = ''
        server {
          listen 8080;
          location / {
            root ${pkgs.nixos-manual.manualHTML};
          }
        }
      '';
    };
  };

  languages = {
    nix = {
      enable = true;
      lsp.package = pkgs.nixd;
    };
    jsonnet = {
      enable = true;
    };
    shell = {
      enable = true;
    };
  };
}
