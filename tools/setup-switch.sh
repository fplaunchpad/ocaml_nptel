#!/usr/bin/env bash
# Install the default-switch build/test dependencies and a separate course
# OxCaml switch. Run from anywhere; re-running preserves existing switches.
# Override OX_SWITCH to use an existing compatible switch.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DEFAULT_SWITCH="$(opam switch show)"
OX_SWITCH="${OX_SWITCH:-nptel-ox}"
# This snapshot pairs the minus-25 compiler with its patched MDX. The
# moving upstream repository can select a newer, incompatible compiler.
OX_REPO_REV="553cc4fb7afd1292478b9dd9ce703786075f0368"
OX_REPO_NAME="nptel-ox-${OX_REPO_REV:0:8}"
OX_REPO_URL="git+https://github.com/oxcaml/opam-repository.git#$OX_REPO_REV"
OX_OVERLAY_URL="file://$REPO_ROOT/tools/oxcaml-opam"
OX_PACKAGES=(ocaml-variants.5.2.0+ox dune.3.21.1 mdx.2.5.0+ox)

note() { printf '\033[1m%s\033[0m\n' "$*"; }

if [ "$DEFAULT_SWITCH" = "$OX_SWITCH" ]; then
  note "Select the default OCaml >= 5.4 switch before running this script."
  exit 1
fi
note "Installing build/test dependencies in '$DEFAULT_SWITCH' ..."
opam install . --switch="$DEFAULT_SWITCH" --deps-only --with-test --yes

if opam switch list -s 2>/dev/null | grep -Fxq "$OX_SWITCH"; then
  # Never silently downgrade a user's newer compiler to satisfy MDX.
  # Request installed packages at their exact versions as constraints.
  # An incompatible switch fails instead of replacing its compiler.
  note "Checking tools in existing OxCaml switch '$OX_SWITCH' ..."
  INSTALLED_TEXT="$(opam list --switch="$OX_SWITCH" \
    --installed --short --columns=package)"
  TOOLS_PRESENT=true
  for package in "${OX_PACKAGES[@]}"; do
    if ! grep -Fxq "$package" <<< "$INSTALLED_TEXT"; then
      TOOLS_PRESENT=false
    fi
  done
  if [ "$TOOLS_PRESENT" = false ]; then
    INSTALLED=()
    while IFS= read -r package; do
      INSTALLED+=("$package")
    done <<< "$INSTALLED_TEXT"
    opam install --switch="$OX_SWITCH" --yes \
      "${INSTALLED[@]}" "${OX_PACKAGES[@]}"
  fi
else
  note "Creating the pinned course OxCaml switch '$OX_SWITCH' ..."
  # The local overlay fixes CPP flag parsing in the old compiler build.
  opam switch create "$OX_SWITCH" \
    --repos="nptel-ox-build=$OX_OVERLAY_URL,$OX_REPO_NAME=$OX_REPO_URL,default" \
    --packages="$(IFS=,; echo "${OX_PACKAGES[*]}")" --no-switch --yes
fi

OX_VERSION="$(opam exec --switch="$OX_SWITCH" -- ocamlc -version)"
if [ "$OX_VERSION" != "5.2.0+ox" ]; then
  note "Expected compiler version 5.2.0+ox; found $OX_VERSION."
  exit 1
fi
# Package installation alone is not evidence that the tools can run.
opam exec --switch="$OX_SWITCH" -- dune --version
opam exec --switch="$OX_SWITCH" -- ocaml-mdx --version
note "Checking the M11 lectures and quiz references ..."
opam exec --switch="$OX_SWITCH" -- dune build @lectures/runtest
opam exec --switch="$OX_SWITCH" -- python3 tools/check-quiz-solutions.py --oxcaml
note "Done. Default switch remains '$DEFAULT_SWITCH'; OxCaml uses '$OX_SWITCH'."
