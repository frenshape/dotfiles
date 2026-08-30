# dotfiles

Cross-platform (macOS / Linux / Windows) dev environment managed with
[chezmoi](https://chezmoi.io): Vim (Python, Markdown, LaTeX), a reproducible
scipy/Jupyter environment via micromamba, and Docker.

## Quick start on a new machine

```bash
# macOS / Linux
sh -c "$(curl -fsLS https://get.chezmoi.io)"
# Windows (PowerShell)
iex "&{$(irm 'https://get.chezmoi.io/ps1')}"

chezmoi init --apply https://github.com/frenshape/dotfiles.git
```

You'll be prompted once: `Setup profile (full/minimal)`. The answer is stored
locally in `~/.config/chezmoi/chezmoi.toml` — it does **not** sync between
machines, so each machine picks its own profile.

To answer non-interactively (scripting a VM, CI, etc.):
```bash
CHEZMOI_PROFILE=minimal chezmoi init --apply https://github.com/frenshape/dotfiles.git
```

## Profiles

| | `full` | `minimal` |
|---|---|---|
| Vim + plugins | yes | yes |
| LaTeX (MacTeX/TeXLive/MiKTeX) | yes | no |
| Node/yarn, Docker | yes | no |
| micromamba + scipy/Jupyter env | yes | no |

## Repo layout / chezmoi naming conventions

- `dot_X` → applied as `~/.X`. (A repo can't easily hold real leading-dot
  filenames, so chezmoi uses this prefix instead.)
- `X.tmpl` → rendered through Go templates before being written. Used
  wherever content branches on OS or profile, e.g. `dot_vimrc.tmpl`.
- `run_onchange_after_X` → not a dotfile at all — a script chezmoi executes
  once all regular files have been written. Re-runs automatically whenever
  **its own rendered content** changes (see gotcha #1 below).
- `executable_X` → applied with the executable bit set, regardless of what
  mode git happened to preserve.
- `.chezmoi.toml.tmpl` → defines the profile prompt. Only processed at
  `chezmoi init` time, not on every `apply`.
- `.chezmoiignore` → files listed here stay in the repo and sync via git,
  but are never copied to `$HOME` (used for this file and `Dockerfile`).

## Vim plugins (vim-plug)

- **Python:** jedi-vim, python-syntax, ALE, vim-python-pep8-indent
- **Markdown:** vim-markdown, markdown-preview.nvim, vim-table-mode
- **LaTeX** (`full` only): vimtex
- **General:** NERDTree, fzf + fzf.vim, vim-fugitive, vim-surround,
  vim-commentary, vim-airline, editorconfig-vim

## Testing changes before they touch a real machine

```bash
docker build --build-arg CACHEBUST=$(date +%s) -t dotfiles-test .
docker run -it dotfiles-test
./verify.sh
```
Test the minimal profile: add `--build-arg PROFILE=minimal`.

This only exercises the **Linux** code path — it's still useful for
catching script bugs and confirming `environment.yml` solves cleanly, but
it can't validate the macOS/Windows-specific branches.

## Known gotchas

Learned the hard way — worth reading before debugging blind:

1. **`run_onchange` scripts only re-run when their own content changes.**
   Editing `dot_vimrc.tmpl` alone won't re-trigger `vim +PlugInstall`. The
   darwin/linux scripts work around this with an embedded content hash:
   `{{ include "dot_vimrc.tmpl" | sha256sum }}`, so any vimrc edit forces
   the script to be considered "changed" too.
2. **vim-plug's `do` install hooks only fire on a plugin's initial clone**,
   never on repeat `:PlugInstall` runs. If a hook fails once (e.g. `yarn`
   wasn't installed yet), it stays silently broken forever. The install
   scripts explicitly check for and rebuild `markdown-preview.nvim`'s
   `node_modules` for this reason, rather than trusting the hook.
3. **Debian/Ubuntu's `nodejs` apt package deliberately excludes corepack.**
   Install it via `npm install -g corepack` instead of assuming it ships
   with Node.
4. **Docker layer caching** reuses a `RUN` step based on the Dockerfile
   instruction text, not on what a `git clone` inside it actually fetches.
   Use `--build-arg CACHEBUST=$(date +%s)` to force a fresh clone when
   testing repo changes.
5. **`git add *` silently skips dotfiles** — that's shell globbing, not
   git. Always use `git add -A` or `git add .` in this repo, since almost
   everything here is a dotfile.
6. **Homebrew `brew` vs `cask`** — GUI apps (Docker Desktop, MacVim,
   MacTeX) are casks; CLI tools are formulae. A few names exist as *both*
   with very different results (`brew "docker"` is CLI-only, no daemon;
   you want `cask "docker-desktop"`).
7. **`micromamba env list`'s table output is indented** — don't match with
   `^envname`; use `grep -qw envname` instead.
8. **Shell rc files only apply to interactive shells.** `.bashrc`/`.zshrc`
   activation hooks (micromamba, PATH exports) don't affect non-interactive
   script execution — the install scripts set `PATH`/`MAMBA_ROOT_PREFIX`
   explicitly rather than relying on rc files being sourced.
9. **`promptStringOnce` ignores `--promptString` in non-interactive
   contexts** (open chezmoi issues #3345, #3834). `.chezmoi.toml.tmpl`
   checks a `CHEZMOI_PROFILE` env var first, falling back to the prompt,
   specifically to work around this in Docker builds.

## Adding something new

- **Vim plugin** → add a `Plug` line in `dot_vimrc.tmpl`. Wrap it in
  `{{- if eq .profile "full" }}...{{- end }}` if it's a heavy/optional
  dependency.
- **macOS package** → `dot_Brewfile`
- **Linux package** → `dot_apt-packages.txt.tmpl` (respects the profile split)
- **Windows package** → the `$packages` array in
  `run_onchange_after_windows-install-packages.ps1.tmpl`

Test in the Docker container before applying to a real machine — nearly
every gotcha above was originally caught there first.
