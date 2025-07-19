{ pkgs, config, ... }:
{
  # Core development packages
  packages = with pkgs; [
    # Nix tooling
    nil # Nix LSP server
    nixd # Alternative Nix LSP (more advanced)
    nixfmt-rfc-style # Nix formatter
    deadnix # Dead code detection
    statix # Linter for Nix
    nix-tree # Dependency tree visualization
    nix-output-monitor # Better build output

    # Development tools
    git
    gh # GitHub CLI
    just # Command runner
    age # For nixsops
    ssh-to-age # Convert SSH keys to age

    # Documentation and validation
    nixos-generators # Generate various formats
    nixos-anywhere # Remote deployment

    # VM testing
    qemu # For nixos tests

    # Additional utilities
    jq # JSON processing
    yq # YAML processing
    fd # File finder
    ripgrep # Text search
    taplo
  ];

  # Development environment variables
  env = {
    # Improve Nix evaluation performance
    NIX_CONFIG = "extra-experimental-features = nix-command flakes";

    # Set up nixsops age key location
    SOPS_AGE_KEY_FILE = "${config.env.DEVENV_ROOT}/secrets/age-key.txt";

    # Enable better error messages
    NIXPKGS_ALLOW_UNFREE = "1";
  };

  # Git hooks for code quality
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

  # Development scripts
  scripts = {
    # Build specific host
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

    # Build specific home configuration
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

    # Run tests
    test = {
      exec = ''
        echo "Running all tests..."
        nix flake check --print-build-logs
      '';
      description = "Run all tests";
    };

    # Run specific test
    test-specific = {
      exec = ''
        if [ -z "$1" ]; then
          echo "Usage: test-specific <test-name>"
          exit 1
        fi
        echo "Running test: $1"
        nix build .#checks.x86_64-linux.$1 --print-build-logs
      '';
      description = "Run a specific test";
    };

    # Generate hardware config with nix-facter
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

    # Initialize secrets
    init-secrets = {
      exec = ''
        echo "Initializing secrets..."
        mkdir -p secrets/keys/{hosts,users}
        if [ ! -f secrets/age-key.txt ]; then
          age-keygen -o secrets/age-key.txt
        fi
        nixsops --config secrets/.sops.yaml init
      '';
      description = "Initialize secrets management";
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

    # Show dependency tree
    deps = {
      exec = ''
        if [ -z "$1" ]; then
          echo "Usage: deps <hostname>"
          exit 1
        fi
        echo "Showing dependency tree for: $1"
        nix-tree .#nixosConfigurations.$1.config.system.build.toplevel
      '';
      description = "Show dependency tree for a configuration";
    };
  };

  # Development services
  services = {
    # Optional: run a local documentation server
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
    };
    jsonnet = {
      enable = true;
    };
    shell = {
      enable = true;
    };
  };

  # Development processes
  processes = {
    # Optional: file watcher for automatic testing
    watch-tests = {
      exec = ''
        ${pkgs.watchman}/bin/watchman-wait . -p '*.nix' --max-events 1 | while read; do
          echo "Files changed, running tests..."
          nix flake check --no-build
        done
      '';
      process-compose = {
        availability = {
          restart = "on_failure";
        };
      };
    };
  };

  # Development containers (optional)
  containers = {
    # You can add container definitions here if needed
  };
}
