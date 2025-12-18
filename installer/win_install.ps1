# SAM2-Tools Windows Installer
Write-Host "=== SAM2-Tools Installer (Windows) ==="

# ---------------------------------------------------------
# Paths
# ---------------------------------------------------------
$RepoURL        = "https://github.com/AyedaOk/sam2-tools.git"
$InstallDir     = "$env:USERPROFILE\sam2-tools"
$VenvDir        = "$InstallDir\venv"
$ConfigDir      = "$env:APPDATA\sam2"
$CheckpointDir  = "$ConfigDir\checkpoints"

$ModelURLs = @(
  "https://dl.fbaipublicfiles.com/segment_anything_2/092824/sam2.1_hiera_tiny.pt",
  "https://dl.fbaipublicfiles.com/segment_anything_2/092824/sam2.1_hiera_small.pt",
  "https://dl.fbaipublicfiles.com/segment_anything_2/092824/sam2.1_hiera_base_plus.pt",
  "https://dl.fbaipublicfiles.com/segment_anything_2/092824/sam2.1_hiera_large.pt"
)

# ---------------------------------------------------------
# 1. Dependency checks
# ---------------------------------------------------------
# ---------------------------------------------------------
# 1. Dependency checks (with winget auto-install)
# ---------------------------------------------------------
$pythonOK = $false
try {
    $out = & python -c "import sys; print(sys.version_info[0])" 2>$null
    if ($out -eq "3") { $pythonOK = $true }
} catch {
    $pythonOK = $false
}


$MissingGit    = -not (Get-Command git -ErrorAction SilentlyContinue)

# VC++ 2015-2022 x64 detection
$VCRedistKey = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
$vcInstalled = $false

if (Test-Path $VCRedistKey) {
    try {
        $vcInstalled = (Get-ItemProperty $VCRedistKey -ErrorAction Stop).Installed -eq 1
    } catch {
        $vcInstalled = $false
    }
}

$MissingVC = -not $vcInstalled

if (-not $pythonOK) {
    Write-Host "[Missing] Python" -ForegroundColor Yellow
}
if ($MissingGit)    { Write-Host "[Missing] Git" -ForegroundColor Yellow }
if ($MissingVC)     { Write-Host "[Missing] Microsoft Visual C++ Redistributable" -ForegroundColor Yellow }

if (-not $pythonOK -or $MissingGit -or $MissingVC) {

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "winget not available. Install missing dependencies manually." -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    $reply = Read-Host "Install missing dependencies using winget? [Y/n]"
    if ($reply -match "^[Nn]") {
        exit 1
    }

    if ($MissingVC) {
        winget install --id Microsoft.VCRedist.2015+.x64 --accept-package-agreements --accept-source-agreements
    }
    if (-not $pythonOK) {
        winget install -e --id Python.Python.3.13 --accept-package-agreements --accept-source-agreements #Tried 3.14 and it didn't work'
    }
    if ($MissingGit) {
        winget install -e --id Git.Git --source winget --accept-package-agreements --accept-source-agreements
    }

    Write-Host ""
    Write-Host "Please close this terminal, reopen PowerShell, and re-run the installer."
    exit 0
}

# Tkinter check (after Python is confirmed)
try {
    $tk = python -c "import tkinter; print('ok')" 2>$null
    if ($tk -ne "ok") { throw }
} catch {
    Write-Host "[Missing] Tkinter (reinstall Python with Tk support)" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------
# 2. Clone or update repo
# ---------------------------------------------------------
if (Test-Path "$InstallDir\.git") {
    Write-Host "Repository exists - updating..."
    git -C $InstallDir pull
} else {
    Write-Host "Cloning repository..."
    git clone $RepoURL $InstallDir
}

# ---------------------------------------------------------
# 3. Create virtual environment
# ---------------------------------------------------------
if (-not (Test-Path $VenvDir)) {
    Write-Host "Creating virtual environment..."
    python -m venv $VenvDir
}

# ---------------------------------------------------------
# 4. Activate virtual environment
# ---------------------------------------------------------
$Activate = "$VenvDir\Scripts\activate.ps1"
if (-not (Test-Path $Activate)) {
    Write-Host "Virtual environment activation failed." -ForegroundColor Red
    exit 1
}

Write-Host "Activating virtual environment..."
. $Activate

# ---------------------------------------------------------
# 5. Install Python dependencies
# ---------------------------------------------------------
Write-Host "Installing Python dependencies..."

$reply = Read-Host "Install CUDA version of PyTorch? [y/N]"
if ($reply -notmatch "^[Yy]") {
    Write-Host "Installing CPU-only PyTorch..."
    pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
}

pip install --upgrade pip
pip install -r "$InstallDir\requirements.txt"

# ---------------------------------------------------------
# 6. Create config
# ---------------------------------------------------------
if (-not (Test-Path "$ConfigDir\config.yaml")) {
    Write-Host "Generating config..."
    python "$InstallDir\main.py" --config
}

# ---------------------------------------------------------
# 7. Model download (optional)
# ---------------------------------------------------------
$reply = Read-Host "Download SAM2 model checkpoints now? [Y/n]"
if ($reply -notmatch "^[Nn]") {

    New-Item -ItemType Directory -Force -Path $CheckpointDir | Out-Null

    foreach ($url in $ModelURLs) {
        $name = Split-Path $url -Leaf
        $dest = "$CheckpointDir\$name"

        if (Test-Path $dest) {
            Write-Host "Already exists: $name"
            continue
        }

        Write-Host "Downloading $name ..."
        try {
            Start-BitsTransfer -Source $url -Destination $dest
        } catch {
            Invoke-WebRequest -Uri $url -OutFile $dest
        }
    }
}

# ---------------------------------------------------------
# 8. Darktable plugin installation (optional)
# ---------------------------------------------------------
$PluginDir = "$env:LOCALAPPDATA\darktable\lua\Custom"

$reply = Read-Host "Install Darktable plugin? [Y/n]"
if ($reply -notmatch "^[Nn]") {

    if (Test-Path "$PluginDir\.git") {
        Write-Host "Updating Darktable plugin..."
        git -C $PluginDir pull
    } else {
        Write-Host "Installing Darktable plugin..."
        Remove-Item $PluginDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path (Split-Path $PluginDir) | Out-Null
        git clone https://github.com/AyedaOk/DT_custom_script.git $PluginDir
    }
} else {
    Write-Host "Skipping Darktable plugin installation."
}

# ---------------------------------------------------------
# 9. Summary
# ---------------------------------------------------------
Write-Host ""
Write-Host "=== Installation complete ===" -ForegroundColor Green
Write-Host "Installed to:  $InstallDir"
Write-Host "Virtual env:   $VenvDir"
Write-Host "Config dir:    $ConfigDir"
Write-Host ""
Write-Host "Run with:"
Write-Host "  $InstallDir\launcher\sam2-tools.bat"
Write-Host "  $InstallDir\launcher\sam2-tools.exe"
Write-Host ""
