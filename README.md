# nix-packages

Self-maintained Nix packages. Each package lives in `packages/<name>` and its NixOS module, when it has one, in `modules/<name>.nix`.

## magpie

Terminal build of [magpie](https://github.com/yetone/magpie) and a NixOS service.
The service keeps configuration, plugins, the Bun cache and home files under
`/var/lib/magpie`.

```nix
{
  inputs.nix-packages.url = "github:wayjamsu/nix-packages";

  outputs = { nixpkgs, nix-packages, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      modules = [
        nix-packages.nixosModules.magpie
        {
          services.magpie = {
            enable = true;
            listen = "127.0.0.1:3425";
            # publicUrl = "https://magpie.example.com";
            # web.enable = true;
            # agy.package = pkgs.agy;
          };
        }
      ];
    };
  };
}
```

Plugins stay in the state directory. Install the Antigravity CLI plugin with
`magpie plugin add @magpie-community/opencode-agy-cli-auth`. Its Google sign-in
is stored by `agy` in the system keyring, which a headless host does not have;
set `GEMINI_API_KEY` through `services.magpie.environmentFiles` to skip it.
