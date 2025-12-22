# Paths
$MainPy = Join-Path $RootDir "main.py"

$LegacyPython = Join-Path $RootDir "venv\Scripts\python.exe"
$UvPython     = Join-Path $RootDir ".venv\Scripts\python.exe"

# Pick python from venv (legacy) or .venv (uv)
if (Test-Path $LegacyPython) {
    $PythonExe = $LegacyPython
} elseif (Test-Path $UvPython) {
    $PythonExe = $UvPython
} else {
    Write-Host "Virtual environment not found (expected venv\ or .venv\)." -ForegroundColor Red
    Write-Host "Re-run the installer to create it." -ForegroundColor Yellow
    exit 1
}

# Ensure we run from project root so relative paths work
Set-Location $RootDir

# Run main
& $PythonExe $MainPy @Args
