# Detect if running inside an EXE or as a loose .ps1
if ($MyInvocation.MyCommand.Path) {
    # Running as .ps1
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    # Running as a compiled EXE (ps2exe)
    $ScriptDir = [System.AppDomain]::CurrentDomain.BaseDirectory
}

# Root of the project (one level above launcher/)
$RootDir = Split-Path $ScriptDir

# Paths
$PythonExe = Join-Path $RootDir "venv\Scripts\python.exe"
$MainPy    = Join-Path $RootDir "main.py"

# Check venv exists
if (!(Test-Path $PythonExe)) {
    Write-Host "Virtual environment not found."
    Write-Host "Please run:"
    Write-Host "  python -m venv venv"
    Write-Host "  venv\Scripts\activate"
    Write-Host "  pip install -r requirements.txt"
    exit 1
}

# Run main
& $PythonExe $MainPy @Args