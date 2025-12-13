Confluence Site Converer
========================

## Overview

## Verified Environment
```
$ opam --version
2.5.0

$ ocaml --version
The OCaml toplevel, version 5.4.0

$ dune --version
3.20.2
```

## Setup
opam is required. See https://opam.ocaml.org/ for installation instructions.

Follow these steps to prepare the environment, install dependencies, build, and run the executable.

1. Update opam and create a switch (example uses OCaml 5.4.0):

```bash
opam update
opam switch create 5.4.0
eval "$(opam env)"
```

2. Install `dune` and basic tooling:

```bash
opam install dune -y
```

3. Generate the package metadata (if needed) and install library dependencies declared by the project:

```bash
# regenerate the generated opam file
dune build confluence_site_converter.opam
# then install only the dependencies required to build this project
opam install --deps-only . -y
```

4. Build the project with Dune:

```bash
dune build
```

5. Run the produced executable (native build):

```bash
# example: show help
./_build/default/bin/main.exe --help
```

Notes:
- If you change the OCaml switch, run `eval "$(opam env)"` again to refresh environment variables.
- If you want a release (optimized) build, use `dune build -p <package> --profile release` or adjust the profile.
- If opam warns about license metadata when installing deps, consider setting an SPDX license identifier in `dune-project` so generated .opam files include an SPDX license (e.g. `license MIT`).

TODO: expand platform-specific notes and any additional runtime configuration.

