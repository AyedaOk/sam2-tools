#!/usr/bin/env bash
set -e

echo "=== SAM2-Tools Installer ==="

# ---------------------------------------------------------
# Paths
# ---------------------------------------------------------
REPO_URL="https://github.com/AyedaOk/sam2-tools.git"
INSTALL_DIR="$HOME/sam2-tools"
VENV_DIR="$INSTALL_DIR/venv"
CONFIG_DIR="$HOME/.config/sam2-tools"
LAUNCHER_PATH="/usr/local/bin/sam2-tools"

# ---------------------------------------------------------
# Helper: colored messages
# ---------------------------------------------------------
ok()   { printf "\033[1;32m%s\033[0m\n" "$1"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$1"; }
err()  { printf "\033[1;31m%s\033[0m\n" "$1"; }

# ---------------------------------------------------------
# 1. Detect distro
# ---------------------------------------------------------
source /etc/os-release

detect_family() {
    case "$ID" in
        ubuntu|debian|linuxmint|pop)
            echo "debian"
            return
            ;;
    esac

    if [[ "$ID_LIKE" == *"debian"* ]]; then
        echo "debian"
        return
    fi
    if [[ "$ID_LIKE" == *"ubuntu"* ]]; then
        echo "debian"
        return
    fi
    if [[ "$ID_LIKE" == *"arch"* ]]; then
        echo "arch"
        return
    fi
    if [[ "$ID_LIKE" == *"fedora"* ]] || [[ "$ID" == "fedora" ]]; then
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
            sudo dnf install -y python3 python3-tkinter git
            ;;
    esac
else
    ok "All dependencies already installed."
fi

# ---------------------------------------------------------
# 3. Clone or update repo
# ---------------------------------------------------------
if [ -d "$INSTALL_DIR/.git" ]; then
    ok "Repository exists — updating..."
    git -C "$INSTALL_DIR" pull
else
    ok "Cloning repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# ---------------------------------------------------------
# 4. Create virtual environment
# ---------------------------------------------------------
if [ ! -d "$VENV_DIR" ]; then
    ok "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
else
    ok "Virtual environment already exists."
fi

# ---------------------------------------------------------
# 5. Activate virtual environment
# ---------------------------------------------------------
SHELL_NAME=$(basename "$SHELL")
ok "Activating virtual environment for shell: $SHELL_NAME"

case "$SHELL_NAME" in
    fish)
        source "$VENV_DIR/bin/activate.fish"
        ;;
    *)
        source "$VENV_DIR/bin/activate"
        ;;
esac

# ---------------------------------------------------------
# 6. Install Python app
# ---------------------------------------------------------
ok "Installing Python dependencies..."
pip install --upgrade pip
pip install -r "$INSTALL_DIR/requirements.txt" || true

# ---------------------------------------------------------
# 7. Create config
# ---------------------------------------------------------
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/config.json" ]; then
    ok "Generating config..."
    (cd "$INSTALL_DIR" && python3 main.py --config)
else
    ok "Config already exists."
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
# 10. Summary
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
