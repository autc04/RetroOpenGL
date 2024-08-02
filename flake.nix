{
  description = "A sample application for Retro68";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    Retro68.url = "github:autc04/Retro68";

    executor.url =
      "git+file:/home/wolfgang/Projects/Executor/executor?submodules=1";
    #mac_emu_nix.url = "github:autc04/mac-emu-nix";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {

      systems =
        [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }:
        let
          appleOpenGLSDKCorePackage = pkgs.fetchurl {
            url =
              "https://staticky.com/dl/ftp.apple.com/developer/opengl/SDK/OpenGL_SDK_1.2_Core.img.bin";
            sha256 = "sha256-25G0MPKysnCX1/ERi2HjywOO/elj+ZoDUGSnbFFtpR8=";
          };
          appleOpenGLSDKCore = pkgs.runCommand "OpenGLSDKCore" { } (''
            mkdir -p $out
            export HOME=$TMPDIR
            ${inputs'.Retro68.packages.tools}/bin/ConvertDiskImage ${appleOpenGLSDKCorePackage} OpenGLSDKCore.dsk

            ${inputs'.Retro68.packages.hfsutils}/bin/hmount OpenGLSDKCore.dsk

            FROM=:
            TO=$out/
            ${inputs'.Retro68.packages.hfsutils}/bin/hls -RF | while IFS= read -r line; do
              case "$line" in
                :*)
                  FORM="$line"
                  TO=$out/$(sed 's#:#/#g' <<< $line)
                  ;;
                *:)
                  echo "mkdir $TO/$(sed 's#:#/#g' <<< $line)"
                  mkdir -p "$TO/$(sed 's#:#/#g' <<< $line)"
                  ;;
                *\*)
                  ${inputs'.Retro68.packages.hfsutils}/bin/hcopy "$FORM$'' + ''
              {line%\*}" "$TO/"
                                ;;
                              *)
                                if [ -n "$line" ]; then
                                  echo "$FORM$line" "$TO/"
                                  ${inputs'.Retro68.packages.hfsutils}/bin/hcopy "$FORM$line" "$TO"
                                fi
                                ;;
                            esac
                          done 
            '');
        in {
          packages.sdk = appleOpenGLSDKCore;

          packages.gl = pkgs.runCommand "gl" { } ''
            mkdir -p $out/include/GL
            cp -r ${appleOpenGLSDKCore}/Headers/*.h $out/include
            cp -r ${appleOpenGLSDKCore}/Headers/*.h $out/include/GL
            mkdir -p $out/lib
            export PATH=$PATH:${inputs'.Retro68.legacyPackages.pkgsCross.powerpc.buildPackages.binutils}/bin
            ${inputs'.Retro68.packages.tools}/bin/MakeImport ${appleOpenGLSDKCore}/Libraries/OpenGLLibraryStub.bin $out/lib/libOpenGLLibraryStub.a
            ${inputs'.Retro68.packages.tools}/bin/MakeImport ${appleOpenGLSDKCore}/Libraries/OpenGLMemoryStub.bin $out/lib/libOpenGLMemoryStub.a
            ${inputs'.Retro68.packages.tools}/bin/MakeImport ${appleOpenGLSDKCore}/Libraries/OpenGLUtilityStub.bin $out/lib/libOpenGLUtilityStub.a
            (
              cd $out/lib 
              ln -s libOpenGLLibraryStub.a libGL.a
              ln -s libOpenGLUtilityStub.a libGLU.a
            )
          '';

          packages.glut =
            inputs'.Retro68.legacyPackages.pkgsCross.powerpc.stdenvUniversal.mkDerivation {
              name = "glut";
              src = "${appleOpenGLSDKCore}/Source/Libraries/GLUT 3.7/";
              buildInputs = [ self'.packages.gl ];
              unpackPhase = ''
                cp "$src"/* .
              '';
              patchPhase = ''
                sed -i 's/timer\.h/Timer\.h/' *.h
                sed -i 's/timer\.h/Timer\.h/' *.c
                sed -i 's/quickdraw\.h/Quickdraw\.h/' *.c
                sed -i 's/displays\.h/Displays\.h/' *.c
                sed -i '/^#define M_PI/d' *.c
                sed -i '/^static char \*strdup.*;/d' *.c
                sed -i '/^static char \*strdup.*/,+9d' *.c
                sed -i 's/^#define/\n#define/' *.h
              '';
              buildPhase = ''
                mkdir -p $out
                $CC -c *.c
                $AR cqs libglut.a *.o
              '';
              installPhase = ''
                mkdir -p $out/include/GL
                mkdir -p $out/lib
                cp -r ${appleOpenGLSDKCore}/Headers/glut.h $out/include/GL/
                cp -r ${appleOpenGLSDKCore}/Headers/glut.h $out/include/
                cp libglut.a $out/lib
              '';
            };

          packages.sample =
            let stdenv = inputs'.Retro68.legacyPackages.pkgsCross.powerpc.stdenvUniversal;
            in stdenv.mkDerivation {
              name = "opengl-sample";
              src = ./.;
              nativeBuildInputs = [
                pkgs.cmake
                pkgs.ninja
                pkgs.nixfmt
                inputs'.Retro68.packages.tools
              ];
              buildInputs = [ self'.packages.gl self'.packages.glut ];
  
              # set an environment variable to the full path of the compiler,
              # for use by c_cpp_properties.json for VSCode Intellisense
              FULL_COMPILER_PATH =
                "${stdenv.cc}/bin/powerpc-apple-macos-g++";
            };

          packages.default = self'.packages.sample;
          devShells.default = self'.packages.sample;

          formatter = pkgs.nixfmt;
        };
    };
}
