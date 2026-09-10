# Course OxCaml compiler overlay

The compiler recipe and `ignore-opam.patch` come from the official
OxCaml opam repository at
`553cc4fb7afd1292478b9dd9ce703786075f0368`. The recipe retains its
upstream source URLs, checksums, authors, and license metadata.

The additional `cpp-flags.patch` preserves equals signs inside the
CC and CPP commands read from `Makefile.config`. The old
`cut -d'=' -f2` truncates `CPP=cc -std=gnu23 -E` to `cc -std`, which
Clang rejects. Using `-f2-` preserves the complete value. This is
needed when building minus-25 with newer Autoconf/compiler probes.
The patch changes build-command parsing, not compiler semantics.

`tools/setup-switch.sh` gives this overlay priority over the pinned
upstream repository, and installs Dune 3.21.1 and MDX 2.5.0+ox.
