#!/usr/bin/env bash
set -e

echo "=== SAM2-Tools Installer ==="

# ---------------------------------------------------------
# Paths
# ---------------------------------------------------------
REPO_URL="https://github.com/AyedaOk/sam2-tools.git"
INSTALL_DIR="$HOME/.local/opt/sam2-tools"
VENV_DIR="$INSTALL_DIR/venv"
CONFIG_DIR="$HOME/.config/sam2"
LAUNCHER_PATH="/usr/local/bin/sam2-tools"
CHECKPOINT_DIR="$HOME/.config/sam2/checkpoints"
TMPDIR="$HOME/.cache/sam2-tools/tmp"

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

download() {
  if command -v curl >/dev/null 2>&1; then
    curl -fL --progress-bar -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$2" "$1"
  else
    err "Neither curl nor wget found."
    exit 1
  fi
}

echo "v0.1"

# ---------------------------------------------------------
# 1. Detect distro
# ---------------------------------------------------------
source /etc/os-release

detect_family() {
    # Direct ID match
    case "$ID" in
        arch)
            echo "arch"
            return
            ;;
        ubuntu | debian | linuxmint | pop | zorin | elementary | neon)
            echo "debian"
            return
            ;;
        fedora | rhel | rocky | almalinux | centos)
            echo "fedora"
            return
            ;;
    esac

    # Fallback to ID_LIKE (when present)
    if [[ "$ID_LIKE" == *"debian"* ]] || [[ "$ID_LIKE" == *"ubuntu"* ]]; then
        echo "debian"
        return
    fi

    if [[ "$ID_LIKE" == *"fedora"* ]] || [[ "$ID_LIKE" == *"rhel"* ]]; then
        echo "fedora"
        return
    fi

    if [[ "$ID_LIKE" == *"arch"* ]]; then
        echo "arch"
        return
    fi

    # Last‑chance fallback: detect pkg manager
    if command -v pacman >/dev/null 2>&1; then
        echo "arch"
        return
    fi

    if command -v apt >/dev/null 2>&1; then
        echo "debian"
        return
    fi

    if command -v dnf >/dev/null 2>&1; then
        echo "fedora"
        return
    fi

    echo "unknown"
}

FAMILY=$(detect_family)
ok "Detected distro family: $FAMILY"

if [[ "$FAMILY" == "unknown" ]]; then
    err "Unsupported Linux distribution."
    exit 1
fi

# ---------------------------------------------------------
# 2. Dependency checks
# ---------------------------------------------------------
missing=false

command -v python3 >/dev/null || missing=true
command -v git >/dev/null || missing=true

# Tkinter detection based on package manager
case "$FAMILY" in
    debian)
        dpkg -l | grep -q python3-tk || missing=true
        ;;
    arch)
        pacman -Q tk >/dev/null 2>&1 || missing=true
        ;;
    fedora)
        rpm -qa | grep -q python3-tkinter || missing=true
        ;;
esac

if $missing; then
    warn "Some dependencies are missing, installing them..."
    case "$FAMILY" in
        debian)
            sudo apt update
            sudo apt install -y python3 python3-tk python3-venv git
            ;;
        arch)
            sudo pacman -Syu --noconfirm python tk git
            ;;
        fedora)
            sudo dnf install -y python3 python3-tkinter git gcc gcc-c++ make python-devel
            ;;
    esac
else
    ok "All dependencies already installed."
fi

# ---------------------------------------------------------
# 3. Clone or update repo
# ---------------------------------------------------------
mkdir -p "$(dirname "$INSTALL_DIR")"
if [ -d "$INSTALL_DIR/.git" ]; then
    ok "Repository exists — updating..."
    git -C "$INSTALL_DIR" pull
else
    ok "Cloning repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# ---------------------------------------------------------
# 4. Create virtual environment and activate the virtual environment
# ---------------------------------------------------------
if [ ! -d "$VENV_DIR" ]; then
    ok "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
else
    ok "Virtual environment already exists."
fi

ok "Activating virtual environment for shell"
source "$VENV_DIR/bin/activate"

# ---------------------------------------------------------
# 5. Install Python app
# ---------------------------------------------------------
ok "Installing Python dependencies..."
rm -rfd "$TMPDIR"
mkdir -p "$TMPDIR"
export TMPDIR                     #This is required on fedora to avoid Errorno 122 disk quota
pip install --upgrade pip
pip install -r "$INSTALL_DIR/requirements.txt"
rm -rfd "$TMPDIR"

# ---------------------------------------------------------
# 6. Create config
# ---------------------------------------------------------
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
    ok "Generating config..."
    (cd "$INSTALL_DIR" && python3 main.py --config)
else
    ok "Config already exists."
fi

# ---------------------------------------------------------
# 7. Download models
# ---------------------------------------------------------

echo ""
warn "SAM2 model checkpoints are required (~3–4GB total)."
read -rp "Download them now? [Y/n] " REPLY
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
# 8. Generate launcher
# ---------------------------------------------------------
ok "Generating system-wide launcher..."

sudo bash -c "cat > $LAUNCHER_PATH" <<EOF
#!/bin/bash
APP_DIR="$INSTALL_DIR"
cd "\$APP_DIR"
"\$APP_DIR/venv/bin/python3" main.py "\$@"
EOF

sudo chmod +x "$LAUNCHER_PATH"

# ---------------------------------------------------------
# 9. Test launcher
# ---------------------------------------------------------
warn "Testing launcher..."
sam2-tools --help || warn "Launcher test failed — but installation may still be OK."

# ---------------------------------------------------------
# 10. Installing Darktable plugin
# ---------------------------------------------------------
echo ""
read -rp "Do you want to install Darktable plugin? [Y/n] " REPLY
REPLY=${REPLY:-Y}

if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    if [ -d "$HOME/.config/darktable/lua" ]; then
        mkdir -p "$HOME/.config/darktable/lua/SAM2"
        curl -fL \
          -o "$HOME/.config/darktable/lua/SAM2/SAM2.lua" \
          https://raw.githubusercontent.com/AyedaOk/DT_custom_script/main/SAM2.lua
        ok "Plugin install completed."
    else
        warn "Darktable Lua directory not found — skipping plugin installation."
    fi
else
    warn "Skipping plugin installation."
fi

# ---------------------------------------------------------
# 11. Summary
# ---------------------------------------------------------
echo ""
ok "=== Installation complete ==="
echo "Installed to: $INSTALL_DIR"
echo "Virtual env:  $VENV_DIR"
echo "Launcher:     /usr/local/bin/sam2-tools"
echo ""
echo "Run with:"
echo "  sam2-tools"
echo ""
