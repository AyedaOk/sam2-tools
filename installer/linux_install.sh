#!/usr/bin/env bash
set -e

echo "=== SAM2-Tools Installer ==="

# ---------------------------------------------------------
# Paths
# ---------------------------------------------------------
REPO_URL="https://github.com/AyedaOk/sam2-tools.git"
INSTALL_DIR="$HOME/.local/opt/sam2-tools"
VENV_DIR="$INSTALL_DIR/.venv"                 # uv default
CONFIG_DIR="$HOME/.config/sam2"
LAUNCHER_PATH="/usr/local/bin/sam2-tools"
CHECKPOINT_DIR="$HOME/.config/sam2/checkpoints"
TMPDIR="$HOME/.cache/sam2-tools/tmp"
PLUGIN_DIR="$HOME/.config/darktable/lua/Custom"

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

has_cmd() { command -v "$1" >/dev/null 2>&1; }

download_to_stdout() {
  if has_cmd curl; then
    curl -fsSL "$1"
  elif has_cmd wget; then
    wget -qO- "$1"
  else
    return 1
  fi
}

download() {
  if has_cmd curl; then
    curl -fL --progress-bar -o "$2" "$1"
  elif has_cmd wget; then
    wget -O "$2" "$1"
  else
    err "Neither curl nor wget found."
    exit 1
  fi
}

# ---------------------------------------------------------
# 1) Detect distro family
# ---------------------------------------------------------
if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  source /etc/os-release
else
  err "Cannot read /etc/os-release. Unsupported system."
  exit 1
fi

detect_family() {
  case "${ID:-}" in
    arch) echo "arch"; return ;;
    ubuntu|debian|linuxmint|pop|zorin|elementary|neon) echo "debian"; return ;;
    fedora|rhel|rocky|almalinux|centos) echo "fedora"; return ;;
  esac

  if [[ "${ID_LIKE:-}" == *"debian"* ]] || [[ "${ID_LIKE:-}" == *"ubuntu"* ]]; then
    echo "debian"; return
  fi
  if [[ "${ID_LIKE:-}" == *"fedora"* ]] || [[ "${ID_LIKE:-}" == *"rhel"* ]]; then
    echo "fedora"; return
  fi
  if [[ "${ID_LIKE:-}" == *"arch"* ]]; then
    echo "arch"; return
  fi

  if has_cmd pacman; then echo "arch"; return; fi
  if has_cmd apt; then echo "debian"; return; fi
  if has_cmd dnf; then echo "fedora"; return; fi

  echo "unknown"
}

FAMILY="$(detect_family)"
ok "Detected distro family: $FAMILY"
if [[ "$FAMILY" == "unknown" ]]; then
  err "Unsupported Linux distribution."
  exit 1
fi

# ---------------------------------------------------------
# 2) Ensure system dependencies (no system Python/Tk)
#     - git
#     - curl/wget
#     - gcc + make (and gcc-c++ on Fedora)
# ---------------------------------------------------------
missing=false

has_cmd git || missing=true
(has_cmd curl || has_cmd wget) || missing=true
has_cmd gcc || missing=true
has_cmd make || missing=true

if $missing; then
  warn "Installing required system dependencies (git + curl + gcc + make)..."
  case "$FAMILY" in
    debian)
      sudo apt update
      sudo apt install -y git curl gcc make
      ;;
    arch)
      sudo pacman -Syu --noconfirm git curl gcc make
      ;;
    fedora)
      sudo dnf install -y git curl gcc gcc-c++ make
      ;;
  esac
else
  ok "All system dependencies already installed."
fi

# ---------------------------------------------------------
# 3) Install uv if missing + ensure PATH
# ---------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"

if ! has_cmd uv; then
  ok "Installing uv..."
  if download_to_stdout "https://astral.sh/uv/install.sh" | sh; then
    ok "uv installed."
  else
    err "Failed to install uv (need curl or wget)."
    exit 1
  fi
fi

export PATH="$HOME/.local/bin:$PATH"
if ! has_cmd uv; then
  err "uv is not on PATH. Try restarting your shell or adding ~/.local/bin to PATH."
  exit 1
fi

# ---------------------------------------------------------
# 4) Clone or update repo
# ---------------------------------------------------------
mkdir -p "$(dirname "$INSTALL_DIR")"
if [ -d "$INSTALL_DIR/.git" ]; then
  ok "Repository exists — updating..."
  git -C "$INSTALL_DIR" pull
else
  ok "Cloning repository..."
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# ---------------------------------------------------------
# 5) Create uv virtual environment (.venv)
# ---------------------------------------------------------
if [ ! -d "$VENV_DIR" ]; then
  ok "Creating virtual environment with uv..."
  uv venv
else
  ok "Virtual environment already exists: $VENV_DIR"
fi

# ---------------------------------------------------------
# 6) Install Python dependencies
# ---------------------------------------------------------
ok "Installing Python dependencies..."
rm -rfd "$TMPDIR"
mkdir -p "$TMPDIR"
export TMPDIR  # required on some systems (e.g., Fedora) to avoid disk quota temp issues

# CPU-only vs CUDA 13 (cu130)
read -rp "Install CPU-only dependencies (no NVIDIA GPU)? [y/N] " CPU_REPLY </dev/tty
CPU_REPLY="${CPU_REPLY:-N}"

if [[ "$CPU_REPLY" =~ ^[Yy]$ ]]; then
  ok "Installing CPU-only PyTorch"
  uv pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
fi

uv pip install -r requirements.txt
rm -rfd "$TMPDIR"

# ---------------------------------------------------------
# 7) Create config
# ---------------------------------------------------------
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
  ok "Generating config..."
  uv run python main.py --config
else
  ok "Config already exists."
fi

# ---------------------------------------------------------
# 8) Download models
# ---------------------------------------------------------
echo ""
warn "SAM2 model checkpoints are required (~1.5GB total)."
read -rp "Download them now? [Y/n] " REPLY </dev/tty
REPLY=${REPLY:-Y}

if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  mkdir -p "$CHECKPOINT_DIR"
  for URL in "${MODEL_URLS[@]}"; do
    FILE="$CHECKPOINT_DIR/$(basename "$URL")"
    if [ -f "$FILE" ]; then
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
# 9) Generate launcher
# ---------------------------------------------------------
ok "Generating system-wide launcher..."

sudo bash -c "cat > '$LAUNCHER_PATH'" <<EOF
#!/bin/bash
APP_DIR="$INSTALL_DIR"
cd "\$APP_DIR" || exit 1
"\$APP_DIR/.venv/bin/python" main.py "\$@"
EOF

sudo chmod +x "$LAUNCHER_PATH"

# ---------------------------------------------------------
# 10) Test launcher
# ---------------------------------------------------------
warn "Testing launcher..."
sam2-tools --help || warn "Launcher test failed — but installation may still be OK."

# ---------------------------------------------------------
# 11) Installing Darktable plugin
# ---------------------------------------------------------
echo ""
read -rp "Do you want to install Darktable plugin? [Y/n] " REPLY </dev/tty
REPLY=${REPLY:-Y}

if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  if [ -d "$PLUGIN_DIR/.git" ]; then
    git -C "$PLUGIN_DIR" pull
  else
    rm -rf "$PLUGIN_DIR"
    git clone https://github.com/AyedaOk/DT_custom_script.git "$PLUGIN_DIR"
  fi
else
  warn "Skipping plugin installation"
fi

# ---------------------------------------------------------
# 12) Summary
# ---------------------------------------------------------
echo ""
ok "=== Installation complete ==="
echo "Installed to: $INSTALL_DIR"
echo "Virtual env:  $VENV_DIR"
echo "Launcher:     $LAUNCHER_PATH"
echo "Plugin:       $PLUGIN_DIR"
echo ""
echo "Run with:"
echo "  sam2-tools"
echo "or:"
echo "  cd \"$INSTALL_DIR\" && uv run python main.py"
echo ""
