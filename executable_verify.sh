#!/bin/bash
# Run after `chezmoi apply` (or inside the test container) to sanity-check
# that everything landed correctly. Non-zero exit on the first hard failure.
set -uo pipefail

pass() { echo "  OK   $1"; }
fail() { echo "  FAIL $1"; FAILED=1; }
FAILED=0

echo "== chezmoi state =="
if [ -z "$(chezmoi diff 2>/dev/null)" ]; then pass "no drift from source"; else fail "chezmoi diff is non-empty"; fi

echo "== core tools on PATH =="
export PATH="$HOME/.local/bin:$PATH"
for cmd in vim git latexmk node yarn rg fzf micromamba; do
    if command -v "$cmd" &>/dev/null; then pass "$cmd found ($(command -v $cmd))"; else fail "$cmd NOT found"; fi
done

echo "== micromamba environment =="
if command -v micromamba &>/dev/null; then
    export MAMBA_ROOT_PREFIX="$HOME/micromamba"
    if micromamba env list 2>/dev/null | grep -qw work; then pass "'work' env exists"; else fail "'work' env not found"; fi
fi

echo "== vim plugins =="
PLUG_STATUS=$(vim -es -u "$HOME/.vimrc" -c 'PlugStatus' -c 'qa!' 2>&1 || true)
if echo "$PLUG_STATUS" | grep -qi 'error'; then
    fail "vim-plug reported errors — run :PlugInstall manually to see details"
else
    pass "vim-plug loaded without errors (run :PlugStatus interactively to confirm each plugin)"
fi

echo
if [ "$FAILED" -eq 0 ]; then
    echo "All checks passed."
else
    echo "One or more checks failed — see FAIL lines above."
    exit 1
fi
