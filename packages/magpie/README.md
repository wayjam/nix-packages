# magpie

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
            agy.package = pkgs.antigravity-cli;
          };
        }
      ];
    };
  };
}
```

Plugins stay in the state directory. With `agy.package` set, install and sign in once as the service user:

```sh
sudo -u magpie env HOME=/var/lib/magpie/home \
  XDG_CONFIG_HOME=/var/lib/magpie/config \
  XDG_CACHE_HOME=/var/lib/magpie/cache \
  XDG_DATA_HOME=/var/lib/magpie/data \
  XDG_STATE_HOME=/var/lib/magpie/state \
  BUN_INSTALL_CACHE_DIR=/var/lib/magpie/cache/bun \
  container=magpie \
  magpie plugin add @magpie-community/opencode-agy-cli-auth

sudo -u magpie env HOME=/var/lib/magpie/home container=magpie \
  agy acp --login

sudo -u magpie env HOME=/var/lib/magpie/home \
  XDG_CONFIG_HOME=/var/lib/magpie/config \
  XDG_CACHE_HOME=/var/lib/magpie/cache \
  XDG_DATA_HOME=/var/lib/magpie/data \
  XDG_STATE_HOME=/var/lib/magpie/state \
  BUN_INSTALL_CACHE_DIR=/var/lib/magpie/cache/bun \
  container=magpie \
  magpie plugin login agy-cli
```

`agy acp --login` is interactive: open its URL, then paste the authorization code into that command. agy writes `/var/lib/magpie/home/.gemini/antigravity-cli/antigravity-oauth-token`. The last command records the existing sign-in in magpie. No keyring service is required.
Set `GEMINI_API_KEY` through `services.magpie.environmentFiles` to use an API key instead.
