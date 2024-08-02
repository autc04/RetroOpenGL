Retro68 OpenGL Sample
====

a.k.a. Using Apple's old OpenGL SDK from Retro68.

This Nix Flake builds the OpenGL SDK libraries, GLUT, and a simple sample program for classic PowerPC MacOS.

## Packages:

You can build each package by running `nix build .#packagename` (e.g., `nix build .#gl`) .
You can also use `nix shell .` (or direnv, if you have that set up) to
get a shell where you can build the sample program using normal cmake commands.

### `sdk`

Apple's OpenGL Core SDK, downloaded on-the-fly from staticky.com and
unpacked for your convenience (using hfsutils and Retro68's `ConvertDiskImage`)

### `gl`

The GL & GLU libraries, converted for use with Retro68 (using the Retro68's `MakeImport` tool)

Once built, this can also be used independently of nix.

### `glut`

GLUT 3.7, compiled from the sources provided in Apple's SDK.
Needed some minor patches.

Once built, this can also be used independently of nix.

### `sample`

a.k.a. `default`.

A sample program that shows a colorful rotating triangle.

