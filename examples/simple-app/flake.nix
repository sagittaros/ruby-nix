{
  description = "A simple ruby app demo";

  nixConfig = {
    substituters = "https://cache.nixos.org https://nixpkgs-ruby.cachix.org";
    trusted-public-keys =
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nixpkgs-ruby.cachix.org-1:vrcdi50fTolOxWCZZkw0jakOnUI1T19oYJ+PRYdK4SM=";
  };

  inputs = {
    nixpkgs.url = "nixpkgs";
    ruby-nix.url = "github:sagittaros/ruby-nix";
    fu.url = "github:numtide/flake-utils";
    bob-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    bob-ruby.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, fu, ruby-nix, bob-ruby }:
    with fu.lib;
    eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ bob-ruby.overlays.default ];
          # You can now refer to packages like:
          #   pkgs."ruby-3"
          #   pkgs."ruby-2.7"
          #   pkgs."ruby-3.0.1"
          # See available versions here:
          #   https://github.com/bobvanderlinden/nixpkgs-ruby/blob/master/ruby/versions.json
        };
        rubyNix = ruby-nix.lib pkgs;

        # TODO generate gemset.nix with bundix
        gemset =
          if builtins.pathExists ./gemset.nix then import ./gemset.nix else { };

        # NOTE If you want to override gem build config, see
        #   https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/ruby-modules/gem-config/default.nix
        # gemConfig = {
        #   cbc-wrapper = _: { buildInputs = [ pkgs.cbc ]; };
        #   gpgme = _: { buildInputs = [ pkgs.pkg-config ]; };
        # };
        gemConfig = { };

      in rec {
        devmode = ruby-nix.presets.devmode;
        finalGemset = devmode // gemset;

        inherit (rubyNix {
          name = "my-rails-app";
          gemset = finalGemset;
          ruby = pkgs."ruby-3.2";
          gemConfig = pkgs.defaultGemConfig // gemConfig;
        })
          env ruby;

        devShells = rec {
          default = dev;
          dev = pkgs.mkShell {
            # NOTE ordering is important here, the head in $PATH always take precedence
            buildInputs = [ ruby env ]
              ++ (with pkgs; [ nodejs-19_x yarn rufo ]);
          };
        };
      });
}
