#!/usr/bin/env bash
# autodl-quick-setup.sh
# Quick bootstrap for AutoDL-like instances
# - conda init
# - install chsrc and switch mirrors for conda & pip only
# - move conda envs/pkgs to /root/autodl-tmp/.conda/{envs,pkgs}
# - set ~/.cache to /root/autodl-tmp/.cache (XDG_CACHE_HOME + symlink)
# Run as root. Usage: bash autodl-quick-setup.sh [-y|--yes]

set -euo pipefail

# ---------------------- config ----------------------
TARGET_ROOT="/root/autodl-tmp"
CONDA_BASE_DIR="${TARGET_ROOT}/.conda"
CONDA_ENVS_DIR="${CONDA_BASE_DIR}/envs"
CONDA_PKGS_DIR="${CONDA_BASE_DIR}/pkgs"
CACHE_TARGET="${TARGET_ROOT}/.cache"
TMP_TARGET="${TARGET_ROOT}/.tmp"
MARK_START="# >>> autodl quick setup >>>"
MARK_END="# <<< autodl quick setup <<<"
AUTO_YES=0
[[ "${1-}" == "-y" || "${1-}" == "--yes" ]] && AUTO_YES=1

# ---------------------- helpers ----------------------
say() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[ERR ]\033[0m %s\n' "$*"; }
hr() { printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '-'; }

need_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    err "Please run as root (e.g., sudo -i && bash autodl-quick-setup.sh)."
    exit 1
  fi
}

confirm() {
  if [[ "$AUTO_YES" -eq 1 ]]; then return 0; fi
  read -r -p "Proceed? [y/N] " ans
  case "${ans:-N}" in
    y|Y|yes|YES) ;;
    *) err "Aborted by user."; exit 1;;
  esac
}

append_block_once() {
  local rc="$1"
  local content="$2"
  touch "$rc"
  if ! grep -qF "$MARK_START" "$rc" 2>/dev/null; then
    {
      echo ""
      echo "$MARK_START"
      echo "$content"
      echo "$MARK_END"
    } >> "$rc"
  fi
}

try_source_conda_sh() {
  # Try common locations so that `conda init` is available
  local tried=(
    "/opt/conda/etc/profile.d/conda.sh"
    "/usr/local/conda/etc/profile.d/conda.sh"
    "${HOME}/miniconda3/etc/profile.d/conda.sh"
    "${HOME}/anaconda3/etc/profile.d/conda.sh"
  )
  for f in "${tried[@]}"; do
    if [[ -f "$f" ]]; then
      # shellcheck disable=SC1090
      source "$f" || true
      return 0
    fi
  done
  return 1
}

install_chsrc() {
  if command -v chsrc >/dev/null 2>&1; then
    say "chsrc already installed: $(chsrc -h 2>/dev/null | head -n1 || echo 'found')"
    return 0
  fi
  say "Installing chsrc (primary)..."
  if curl -fsSL https://chsrc.run/posix | bash -s -- -l en; then
    say "chsrc installed via chsrc.run."
    return 0
  fi
  warn "Primary install failed. Trying fallback (gitee)..."
  curl -fsSL https://gitee.com/RubyMetric/chsrc/raw/main/tool/installer.sh | bash -s -- -l en
  say "chsrc installed via gitee fallback."
}

safe_symlink() {
  local target="$1" linkpath="$2"
  mkdir -p "$(dirname "$linkpath")"
  if [[ -L "$linkpath" ]]; then
    local cur
    cur="$(readlink -f "$linkpath" || true)"
    if [[ "$cur" != "$target" ]]; then
      rm -f "$linkpath"
      ln -s "$target" "$linkpath"
    fi
  elif [[ -e "$linkpath" ]]; then
    local bak="${linkpath}.bak.$(date +%Y%m%d%H%M%S)"
    warn "$linkpath exists; moving to $bak"
    mv "$linkpath" "$bak"
    ln -s "$target" "$linkpath"
  else
    ln -s "$target" "$linkpath"
  fi
}

# ---------------------- preflight ----------------------
need_root

hr
cat <<EOF
This script will perform:

1) Make directories:
   - ${CONDA_ENVS_DIR}
   - ${CONDA_PKGS_DIR}
   - ${CACHE_TARGET}
   - ${TMP_TARGET}

2) Configure cache & tmp:
   - Export XDG_CACHE_HOME=${CACHE_TARGET} in shell RC
   - Symlink ~/.cache -> ${CACHE_TARGET}
   - Export TMPDIR/TEMP/TMP=${TMP_TARGET} in shell RC
   - Symlink ~/.tmp -> ${TMP_TARGET}

3) Configure conda:
   - Export CONDA_ENVS_DIRS=${CONDA_ENVS_DIR}
   - Export CONDA_PKGS_DIRS=${CONDA_PKGS_DIR}
   - Run: conda init (bash & zsh if available)

4) Install chsrc and switch mirrors:
   - Install chsrc (posix installer; fallback to gitee)
   - chsrc set conda
   - chsrc set pip

5) Configure screen UTF-8 defaults:
   - Ensure UTF-8 settings in ~/.screenrc

6) Configure Vim UTF-8 defaults:
   - Ensure UTF-8 settings in ~/.vimrc

After completion: close this terminal and open a new one.
EOF
hr
confirm

# ---------------------- actions ----------------------
say "Creating target directories..."
mkdir -p "${CONDA_ENVS_DIR}" "${CONDA_PKGS_DIR}" "${CACHE_TARGET}" "${TMP_TARGET}"
chown -R root:root "${TARGET_ROOT}"

say "Configuring ~/.cache -> ${CACHE_TARGET} and XDG_CACHE_HOME..."
safe_symlink "${CACHE_TARGET}" "${HOME}/.cache"

# We'll also persist environment variables in RC files for future shells
BASHRC="${HOME}/.bashrc"
ZSHRC="${HOME}/.zshrc"
ENV_BLOCK=$(cat <<EOT
# AutoDL quick setup: conda & cache locations
export XDG_CACHE_HOME="${CACHE_TARGET}"
export CONDA_ENVS_DIRS="${CONDA_ENVS_DIR}"
export CONDA_PKGS_DIRS="${CONDA_PKGS_DIR}"
export TMPDIR="${TMP_TARGET}"
export TEMP="${TMP_TARGET}"
export TMP="${TMP_TARGET}"
EOT
)
append_block_once "${BASHRC}" "${ENV_BLOCK}"
append_block_once "${ZSHRC}"  "${ENV_BLOCK}"

# Export to current session so the following commands (pip/chsrc) see them
export XDG_CACHE_HOME="${CACHE_TARGET}"
export CONDA_ENVS_DIRS="${CONDA_ENVS_DIR}"
export CONDA_PKGS_DIRS="${CONDA_PKGS_DIR}"
export TMPDIR="${TMP_TARGET}"
export TEMP="${TMP_TARGET}"
export TMP="${TMP_TARGET}"

say "Configuring ~/.tmp -> ${TMP_TARGET} and TMPDIR/TEMP/TMP..."
safe_symlink "${TMP_TARGET}" "${HOME}/.tmp"

say "Looking for conda..."
if ! command -v conda >/dev/null 2>&1; then
  if try_source_conda_sh; then
    say "conda.sh sourced."
  fi
fi

if command -v conda >/dev/null 2>&1; then
  say "Running conda init for bash/zsh..."
  # These may return non-zero if already initialized; ignore errors
  conda init bash || true
  conda init zsh  || true
else
  warn "conda executable not found. Skipping 'conda init'. If conda exists in a non-standard path, initialize it manually later."
fi

say "Installing chsrc..."
install_chsrc
if ! command -v chsrc >/dev/null 2>&1; then
  err "Failed to install chsrc. Please check network and try again."
  exit 1
fi

say "Switching mirrors using chsrc (only conda & pip)..."
# chsrc may prompt in some environments; but defaults should be non-interactive
if ! chsrc set conda; then
  warn "chsrc set conda failed. You can retry later with: chsrc set conda"
fi
if ! chsrc set pip; then
  warn "chsrc set pip failed. You can retry later with: chsrc set pip"
fi

say "Configuring ~/.screenrc for UTF-8 defaults..."
SCREENRC="${HOME}/.screenrc"
SCREEN_BLOCK=$(cat <<'EOT'
# GNU screen UTF-8 defaults
defutf8 on
defencoding utf8
encoding UTF-8 UTF-8
EOT
)
append_block_once "${SCREENRC}" "${SCREEN_BLOCK}"

say "Configuring ~/.vimrc for UTF-8 defaults..."
VIMRC="${HOME}/.vimrc"
VIM_BLOCK=$(cat <<'EOT'
" Vim UTF-8 defaults
set termencoding=utf-8
set encoding=utf8
set fileencodings=utf8,ucs-bom,gbk,cp936,gb2312,gb18030
EOT
)
append_block_once "${VIMRC}" "${VIM_BLOCK}"

hr
say "Done."
cat <<'EOF'
✅ All set.

Next steps:
  1) Close this terminal window/tab
  2) Open a fresh terminal (so conda init & env vars take effect)

Tip:
  - To re-run or adjust mirrors later:
      chsrc ls conda
      chsrc set conda <mirror>
      chsrc reset conda
      chsrc set pip <mirror>
EOF
