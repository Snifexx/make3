{
  description = "Shell";

  inputs = {
    nixpkgs.url = "nixpkgs/648f70160c03151bc2121d179291337ad6bc564b";
  };

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        c3c c3-lsp
      ];
      
      shellHook = ''
        export SHELL="$(which fish)"
        $SHELL
      '';
    };
  };
}
