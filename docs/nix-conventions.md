# Nix conventions

This document describes the conventions used in this repository for Nix code. These are not hard rules, but rather guidelines to keep the codebase consistent and maintainable.

Please update this document if you make changes to the codebase that deviate from these conventions, or if you think a new convention should be added.

## Tree structure

We use the `import-tree` function to import all modules and packages from their respective directories.
This allows us to easily add new modules and packages without boilerplate glue code.
Namely it gets rid of the need for default.nix to import all files in a directory.

> files/directories with '_' prefix are ignored by import-tree (e.g. `_private.nix` or `_modules/`)
> It can be used as a "private" modifier for modules meant to be imported locally but not exposed to the rest of the codebase.

Each module is imported as a `flake-parts` part.
That means every module has access to the top-level [flake-parts structure](https://flake.parts/getting-started) (e.g. `flake`, `perSystem`, `imports`, `systems`).

This structure requires "absolute" option paths (e.g. `flake.packages.dartkitos-update` instead of `pkgs.dartkitos-update`) which is a bit more verbose but also more explicit.

It makes it easier to understand what part of the codebase a module or package belongs to (e.g. `self.packages` vs `self.nixosModules`).
Every module has the same top-level structure, so it's easy to navigate and find what you're looking for.

It also allows us to easily reference other modules and packages without having to worry about import order or circular dependencies.

When it doesn't make sense to expose a module or package to the rest of the codebase, we can still define custom attribute sets.
For those, remember to mark them as private (with '_' prefix) and import them locally in the module that uses them.
