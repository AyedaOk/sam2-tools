#!/usr/bin/env bash
set -e

echo "=== SAM2-Tools Installer (macOS / Apple Silicon) ==="

# ---------------------------------------------------------
# Paths
# ---------------------------------------------------------
REPO_URL="https://github.com/AyedaOk/sam2-tools.git"

INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications/sam2-tools}"
VENV_DIR="$INSTALL_DIR/venv"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sam2"
CHECKPOINT_DIR="$CONFIG_DIR/checkpoints"

PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/darktable/lua/Custom"

# Generated user launcher
LAUNCHER_OUT="${LAUNCHER_OUT:-$HOME/Applications/sam2-tools.command}"

MODEL_URLS=(
  "https://dl.fbaipublicfiles.com/segment_anything_2/092824/sam2.1_hiera_tiny.pt"
  "https://dl.fbaipublicfiles.com/segment_anything_2/092824/sam2.1_hiera_small.pt"
  "https://dl.fbaipublicfiles.com/segment_anything_2/092824/sam2.1_hiera_base_plus.pt"
  "https://dl.fbaipublicfiles.com/segment_anything_2/092824/sam2.1_hiera_large.pt"
)

# ---------------------------------------------------------
# Helpers
# ---------------------------------------------------------
ok()   { printf "\033[1;32m%s\033[0m\n" "$1"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$1"; }
err()  { printf "\033[1;31m%s\033[0m\n" "$1"; }

confirm() {
  # Usage: confirm "Question" "Y"|"N"
  local prompt="$1"
  local default="${2:-Y}"
  local reply

  if [[ "$default" == "Y" ]]; then
    read -rp "$prompt [Y/n] " reply </dev/tty || true
    reply="${reply:-Y}"
  else
    read -rp "$prompt [y/N] " reply </dev/tty || true
    reply="${reply:-N}"
  fi

  [[ "$reply" =~ ^[Yy]$ ]]
}

download() {
  # download URL OUTFILE (resumable + retries)
  curl -fL --progress-bar \
    --continue-at - \
    --retry 5 --retry-delay 2 --retry-all-errors \
    -o "$2" "$1"
}


# ---------------------------------------------------------
# 1. Platform checks 
# ---------------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
  err "This installer is for macOS only."
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  err "Apple Silicon (arm64) only for now."
  exit 1
fi

ok "Detected macOS (arm64)."

# ---------------------------------------------------------
# 2. Homebrew (required)
# ---------------------------------------------------------
BREW="$(command -v brew 2>/dev/null || true)"
if [[ -z "$BREW" && -x "/opt/homebrew/bin/brew" ]]; then
  BREW="/opt/homebrew/bin/brew"
fi

if [[ -z "$BREW" ]]; then
  warn "Homebrew not found (required)."
  if confirm "Install Homebrew now?" "Y"; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    BREW="/opt/homebrew/bin/brew"
  else
    err "Homebrew is required. Aborting."
    exit 1
  fi
fi

# Make sure brew is in PATH for this script run
eval "$("$BREW" shellenv)"
ok "Using Homebrew: $BREW"

# ---------------------------------------------------------
# 3. Install dependencies (git, python, python-tk)
# ---------------------------------------------------------
ok "Installing dependencies (git, python, python-tk)..."
brew update
brew install git python python-tk

# Do NOT rely on plain `python3` in PATH; use Homebrew prefix directly
BREW_PREFIX="$(brew --prefix)"
PYTHON_BIN="$BREW_PREFIX/bin/python3"
if [[ ! -x "$PYTHON_BIN" ]]; then
  err "Homebrew python3 not found at: $PYTHON_BIN"
  err "Check: ls \"$BREW_PREFIX/bin/python3*\""
  exit 1
fi
ok "Using Python: $PYTHON_BIN"

# ---------------------------------------------------------
# 4. Clone or update repo
# ---------------------------------------------------------
mkdir -p "$(dirname "$INSTALL_DIR")"
if [[ -d "$INSTALL_DIR/.git" ]]; then
  ok "Repository exists — updating..."
  git -C "$INSTALL_DIR" pull
elif [[ -e "$INSTALL_DIR" ]]; then
  err "Install path exists but is not a git repo:"
  err "  $INSTALL_DIR"
  err "Move it aside or delete it, then re-run."
  exit 1
else
  ok "Cloning repository..."
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

# ---------------------------------------------------------
# 5. Create virtual environment and activate the virtual environment
# ---------------------------------------------------------
if [[ ! -d "$VENV_DIR" ]]; then
  ok "Creating virtual environment..."
  "$PYTHON_BIN" -m venv "$VENV_DIR"
else
  ok "Virtual environment already exists."
fi

ok "Activating virtual environment for shell"
# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"

# ---------------------------------------------------------
# 6. Install PyTorch first then requirements
# ---------------------------------------------------------
ok "Upgrading pip..."
python -m pip install --upgrade pip

ok "Installing PyTorch first (CPU index)..."
# Note: if requirements.txt pins torch/torchvision to different versions,
# pip may later adjust them during the requirements install.
python -m pip install torch torchvision \
  --index-url https://download.pytorch.org/whl/cpu \
  --extra-index-url https://pypi.org/simple

ok "Installing Python dependencies from requirements.txt..."
python -m pip install -r "$INSTALL_DIR/requirements.txt"

# ---------------------------------------------------------
# 7. Create config
# ---------------------------------------------------------
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/config.yaml" ]]; then
  ok "Generating config..."
  (cd "$INSTALL_DIR" && python main.py --config)
else
  ok "Config already exists."
fi

# ---------------------------------------------------------
# 8. Download models
# ---------------------------------------------------------
echo ""
warn "SAM2 model checkpoints are required (~1.5GB total)."
if confirm "Download them now?" "Y"; then
  mkdir -p "$CHECKPOINT_DIR"
  for URL in "${MODEL_URLS[@]}"; do
    FILE="$CHECKPOINT_DIR/$(basename "$URL")"
    if [[ -f "$FILE" ]]; then
      ok "Already exists: $(basename "$FILE")"
    else
      ok "Downloading $(basename "$FILE")..."
      download "$URL" "$FILE"
    fi
  done
  ok "Model download complete."
else
  warn "Skipping model download."
  warn "You must place checkpoints in:"
  warn "  $CHECKPOINT_DIR"
fi

# ---------------------------------------------------------
# 9. Generate Finder/Darktable launcher (.command)
# ---------------------------------------------------------
ok "Generating launcher: $LAUNCHER_OUT"
mkdir -p "$HOME/Applications"

if [[ -f "$LAUNCHER_OUT" ]]; then
  warn "Existing launcher found — backing up to: $LAUNCHER_OUT.bak"
  cp -f "$LAUNCHER_OUT" "$LAUNCHER_OUT.bak"
fi

cat > "$LAUNCHER_OUT" <<EOF
#!/bin/bash
set -e
APP_DIR="$INSTALL_DIR"
VENV_PY="\$APP_DIR/venv/bin/python3"

cd "\$APP_DIR"

if [ ! -x "\$VENV_PY" ]; then
  echo "Could not find venv python at: \$VENV_PY"
  echo "Re-run the installer to recreate the venv."
  exit 1
fi

exec "\$VENV_PY" main.py "\$@"
EOF

chmod +x "$LAUNCHER_OUT"

# ---------------------------------------------------------
# 10. Installing Darktable plugin (optional)
# ---------------------------------------------------------
echo ""
if confirm "Do you want to install Darktable plugin?" "Y"; then
  mkdir -p "$(dirname "$PLUGIN_DIR")"
  if [[ -d "$PLUGIN_DIR/.git" ]]; then
    ok "Plugin repo exists — updating..."
    git -C "$PLUGIN_DIR" pull
  else
    rm -rf "$PLUGIN_DIR"
    ok "Cloning plugin repo..."
    git clone https://github.com/AyedaOk/DT_custom_script.git "$PLUGIN_DIR"
  fi
else
  warn "Skipping plugin installation."
fi

# ---------------------------------------------------------
# 11. Summary
# ---------------------------------------------------------
echo ""
ok "=== Installation complete ==="
echo "Installed to:  $INSTALL_DIR"
echo "Virtual env:   $VENV_DIR"
echo "Launcher:      $LAUNCHER_OUT"
echo "Config:        $CONFIG_DIR/config.yaml"
echo "Checkpoints:   $CHECKPOINT_DIR"
echo "Plugin:        $PLUGIN_DIR"
echo ""
echo "Run with:"
echo "  \"$LAUNCHER_OUT\""
echo ""
warn "If pip fails building wheels, install Xcode CLT with: xcode-select --install (then re-run)."
