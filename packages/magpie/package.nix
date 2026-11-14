{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule (finalAttrs: {
  pname = "magpie";
  version = "0.1.3962";

  src = fetchFromGitHub {
    owner = "yetone";
    repo = "magpie";
    tag = "v${finalAttrs.version}";
    hash = "sha256-FbhVpmAUbW7pfkryFltKIX25tU7mu2Cj+3CANS5BGAg=";
  };

  vendorHash = "sha256-nxO7lvPHI5L8iHuVfjPBjSUOui/OdlQ/9uGW/7GpmtE=";

  env.CGO_ENABLED = "0";

  tags = ["nogui"];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  subPackages = ["."];

  doCheck = false;

  passthru.updateScript = nix-update-script {};

  meta = {
    description = "Local gateway that serves any configured model to any agent";
    homepage = "https://github.com/yetone/magpie";
    changelog = "https://github.com/yetone/magpie-releases/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "magpie";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
