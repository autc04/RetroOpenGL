{
  description = "A sample application for Retro68";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    Retro68.url = "github:autc04/Retro68";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {

      # support all host platforms that Retro68 supports
      systems = builtins.attrNames inputs.Retro68.packages;

      perSystem = { config, self', inputs', pkgs, system, ... }: {

        # Package 'sdk'
        # Apple's OpenGL 'core' SDK (the smaller package without the sample code),
        # downloaded and unpacked.

        packages.sdk = let
          appleOpenGLSDKCorePackage = pkgs.fetchurl {
            url =
              "https://staticky.com/dl/ftp.apple.com/developer/opengl/SDK/OpenGL_SDK_1.2_Core.img.bin";
            sha256 = "sha256-25G0MPKysnCX1/ERi2HjywOO/elj+ZoDUGSnbFFtpR8=";
          };
        in pkgs.runCommand "OpenGLSDKCore" { } (''
          mkdir -p $out
          export HOME=$TMPDIR
          ${inputs'.Retro68.packages.tools}/bin/ConvertDiskImage ${appleOpenGLSDKCorePackage} OpenGLSDKCore.dsk

          # Use hfsutils to extract files from the disk image.
          ${inputs'.Retro68.packages.hfsutils}/bin/hmount OpenGLSDKCore.dsk

          # Unfortunately, hfsutils doesn't support recursive copies, so we have to do a loop
          # based on the recursive listing functionality of the `hls` command.
          FROM=:
          TO=$out/
          ${inputs'.Retro68.packages.hfsutils}/bin/hls -RF | while IFS= read -r line; do
            case "$line" in
              :*)
                # hls outputs a line starting with a colon for each directory it lists,
                # followed by directory's contents with no leading colons.
                FORM="$line"
                TO=$out/$(sed 's#:#/#g' <<< $line)
                ;;
              "")
                # Empty line means the end of the directory listing.
                ;;
              *:)
                # Trailing colon means it's a directory, create the destination directory.
                echo "mkdir $TO/$(sed 's#:#/#g' <<< $line)"
                mkdir -p "$TO/$(sed 's#:#/#g' <<< $line)"
                ;;
              *)
                # Regular files.
                echo "$FORM$line" "$TO/"
                ${inputs'.Retro68.packages.hfsutils}/bin/hcopy "$FORM$line" "$TO"
                ;;
            esac
          done 
        '');

        # Package 'gl'
        # OpenGL libraries and headers from the SDK, converted for use with Retro68.

        packages.gl = pkgs.runCommand "gl" { } ''
          mkdir -p $out/include/GL
          # Allow the headers to be accessed via both #include <GL/gl.h> and #include <gl.h>
          cp -r ${self'.packages.sdk}/Headers/*.h $out/include
          cp -r ${self'.packages.sdk}/Headers/*.h $out/include/GL

          mkdir -p $out/lib
          # The MakeImport tool needs powerpc-apple-macos-as and powerpc-apple-macos-ld to be in the PATH.
          export PATH=$PATH:${inputs'.Retro68.legacyPackages.pkgsCross.powerpc.buildPackages.binutils}/bin
          ${inputs'.Retro68.packages.tools}/bin/MakeImport ${self'.packages.sdk}/Libraries/OpenGLLibraryStub.bin $out/lib/libOpenGLLibraryStub.a
          ${inputs'.Retro68.packages.tools}/bin/MakeImport ${self'.packages.sdk}/Libraries/OpenGLMemoryStub.bin $out/lib/libOpenGLMemoryStub.a
          ${inputs'.Retro68.packages.tools}/bin/MakeImport ${self'.packages.sdk}/Libraries/OpenGLUtilityStub.bin $out/lib/libOpenGLUtilityStub.a

          # also support the traditional cross-platform names for the libraries
          (
            cd $out/lib 
            ln -s libOpenGLLibraryStub.a libGL.a
            ln -s libOpenGLUtilityStub.a libGLU.a
          )
        '';

        # Package 'glut'
        # GLUT library from the SDK, compiled for PowerPC.

        packages.glut =
          inputs'.Retro68.legacyPackages.pkgsCross.powerpc.stdenvUniversal.mkDerivation {
            name = "glut";
            src = "${self'.packages.sdk}/Source/Libraries/GLUT 3.7/";
            buildInputs = [ self'.packages.gl ];
            unpackPhase = ''
              cp "$src"/* .
            '';
            patchPhase = ''
              # Apply some patches to the GLUT source code.
              # First, some header files are included with the wrong case, which is not a problem on MacOS.
              sed -i 's/timer\.h/Timer\.h/' *.h
              sed -i 's/timer\.h/Timer\.h/' *.c
              sed -i 's/quickdraw\.h/Quickdraw\.h/' *.c
              sed -i 's/displays\.h/Displays\.h/' *.c

              # Next, remove some definitions that are already provided by the standard library in Retr68.
              sed -i '/^#define M_PI/d' *.c
              sed -i '/^static char \*strdup.*;/d' *.c
              sed -i '/^static char \*strdup.*/,+9d' *.c

              # Finally, some multiline #define statements in the header files incorrectly end with a backslash,
              # which a modern preprocessor complains about. Adding an empty line before every #define is a quick fix.
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
              cp -r ${self'.packages.sdk}/Headers/glut.h $out/include/GL/
              cp -r ${self'.packages.sdk}/Headers/glut.h $out/include/
              cp libglut.a $out/lib
            '';
          };

        # Package 'sample'
        # A sample application that uses OpenGL and GLUT.

        packages.sample = let
          stdenv =
            inputs'.Retro68.legacyPackages.pkgsCross.powerpc.stdenvUniversal;
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
          FULL_COMPILER_PATH = "${stdenv.cc}/bin/powerpc-apple-macos-g++";
        };

        # Package 'default': a plain `nix build` will build the sample.
        packages.default = self'.packages.sample;

        # Development shell: `nix develop` will open a shell suitable for building the sample
        devShells.default = self'.packages.sample;

        # Formatter for formatting this .nix file
        formatter = pkgs.nixfmt;
      };
    };
}
