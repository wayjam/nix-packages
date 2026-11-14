{
  description = "Self-maintained Nix packages";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    overlay = final: _: {
      magpie = final.callPackage ./packages/magpie/package.nix {};
    };
  in {
    overlays.default = overlay;

    packages = forAllSystems (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [overlay];
        };
      in {
        inherit (pkgs) magpie;
      }
    );

    nixosModules.magpie = {...}: {
      imports = [./packages/magpie/module.nix];
      nixpkgs.overlays = [overlay];
    };

    checks = forAllSystems (
      system: let
        evaluated = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.magpie
            {
              services.magpie = {
                enable = true;
                listen = "127.0.0.1:3425";
                publicUrl = "https://magpie.example.invalid";
                web.enable = true;
                web.listen = "127.0.0.1:3430";
                environment.AGY_BRIDGE_MAX_PROCS = "4";
              };
              system.stateVersion = "26.05";
            }
          ];
        };
        service = evaluated.config.systemd.services.magpie;
        expect = name: value:
          nixpkgs.lib.assertMsg (service.environment.${name} == value)
          "${name}: got ${toString service.environment.${name}}, expected ${value}";
      in {
        module = assert expect "MAGPIE_ADDR" "127.0.0.1:3425";
        assert expect "MAGPIE_PUBLIC_URL" "https://magpie.example.invalid";
        assert expect "XDG_CONFIG_HOME" "/var/lib/magpie/config";
        assert expect "XDG_CACHE_HOME" "/var/lib/magpie/cache";
        assert expect "XDG_DATA_HOME" "/var/lib/magpie/data";
        assert expect "XDG_STATE_HOME" "/var/lib/magpie/state";
        assert expect "HOME" "/var/lib/magpie/home";
        assert expect "BUN_INSTALL_CACHE_DIR" "/var/lib/magpie/cache/bun";
        assert expect "AGY_BRIDGE_MAX_PROCS" "4";
        assert nixpkgs.lib.assertMsg (
          service.serviceConfig.ExecStart
          == "${nixpkgs.lib.getExe evaluated.config.services.magpie.package} web --addr 127.0.0.1:3430 --no-open"
        ) "ExecStart: ${service.serviceConfig.ExecStart}";
        assert nixpkgs.lib.assertMsg (service.environment.MAGPIE_BUN or "" != "") "MAGPIE_BUN unset";
          nixpkgs.legacyPackages.${system}.runCommand "magpie-module-check" {} "touch $out";

        serve = let
          served = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.magpie
              {
                services.magpie.enable = true;
                system.stateVersion = "26.05";
              }
            ];
          };
          unit = served.config.systemd.services.magpie;
        in
          assert nixpkgs.lib.assertMsg (
            unit.serviceConfig.ExecStart
            == "${nixpkgs.lib.getExe served.config.services.magpie.package} serve"
          ) "ExecStart: ${unit.serviceConfig.ExecStart}";
          assert nixpkgs.lib.assertMsg (
            nixpkgs.lib.all (
              dir:
                nixpkgs.lib.elem "d ${dir} 0700 magpie magpie - -" served.config.systemd.tmpfiles.rules
            ) [
              "/var/lib/magpie"
              "/var/lib/magpie/config"
              "/var/lib/magpie/cache"
              "/var/lib/magpie/cache/bun"
              "/var/lib/magpie/data"
              "/var/lib/magpie/state"
              "/var/lib/magpie/home"
            ]
          ) "magpie state directories are missing";
            nixpkgs.legacyPackages.${system}.runCommand "magpie-serve-check" {} "touch $out";
      }
    );
  };
}
