# Simulates a fresh Linux machine restoring your environment from scratch.
# Build:
#   docker build -t dotfiles-test .
# Run:
#   docker run -it dotfiles-test
#
# Note: this only exercises the Linux code path (run_onchange_linux-*.sh).
# It's still useful for catching syntax errors, missing packages, and
# whether the environment.yml solves cleanly — but it can't test the
# macOS/Windows branches of your vimrc or scripts.

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl git sudo ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Non-root user so `sudo` in the install scripts behaves like it would
# on a real machine, instead of silently being root already.
RUN useradd -m -s /bin/bash tester \
    && echo "tester ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER tester
WORKDIR /home/tester
ENV HOME=/home/tester

RUN sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/bin"
ENV PATH="/home/tester/bin:${PATH}"

# Point this at your repo. Override at build time to test a branch/fork:
#   docker build --build-arg DOTFILES_REPO=... -t dotfiles-test .
ARG DOTFILES_REPO=https://github.com/frenshape/dotfiles.git

# Which profile to test — "full" or "minimal". Set as an env var, not a
# chezmoi flag: promptStringOnce currently ignores --promptString in
# non-interactive contexts (see chezmoi issues #3345, #3834), so we bypass
# the prompt entirely by having .chezmoi.toml.tmpl check this env var first.
#   docker build --build-arg PROFILE=minimal -t dotfiles-test-minimal .
ARG PROFILE=full
ENV CHEZMOI_PROFILE=${PROFILE}

# Forces the layer below to re-run even when nothing else in this
# Dockerfile changed — pass a fresh value (e.g. a timestamp) so Docker
# can't reuse a stale cached clone of your repo:
#   docker build --build-arg CACHEBUST=$(date +%s) -t dotfiles-test .
ARG CACHEBUST=1

# The real end-to-end test: exactly what a new machine would run.
RUN chezmoi init --apply "${DOTFILES_REPO}"

CMD ["/bin/bash", "-l"]
