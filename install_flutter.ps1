# Flutter Installation Script for Windows
Write-Host "Installing Flutter..." -ForegroundColor Green

# Create flutter directory
$flutterPath = "C:\flutter"
if (!(Test-Path $flutterPath)) {
    New-Item -ItemType Directory -Path $flutterPath -Force
    Write-Host "Created directory: $flutterPath" -ForegroundColor Yellow
}

# Download Flutter SDK
$flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.5-stable.zip"
$zipPath = "$env:TEMP\flutter_windows.zip"

Write-Host "Downloading Flutter SDK..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $flutterUrl -OutFile $zipPath
    Write-Host "Download completed!" -ForegroundColor Green
} catch {
    Write-Host "Download failed: $_" -ForegroundColor Red
    exit 1
}

# Extract Flutter
Write-Host "Extracting Flutter..." -ForegroundColor Yellow
try {
    Expand-Archive -Path $zipPath -DestinationPath "C:\" -Force
    Write-Host "Extraction completed!" -ForegroundColor Green
} catch {
    Write-Host "Extraction failed: $_" -ForegroundColor Red
    exit 1
}

# Add to PATH
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$flutterBinPath = "C:\flutter\bin"

if ($currentPath -notlike "*$flutterBinPath*") {
    $newPath = "$currentPath;$flutterBinPath"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    Write-Host "Added Flutter to PATH" -ForegroundColor Green
} else {
    Write-Host "Flutter already in PATH" -ForegroundColor Yellow
}

# Clean up
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

Write-Host "Flutter installation completed!" -ForegroundColor Green
Write-Host "Please restart your terminal and run 'flutter doctor' to verify installation." -ForegroundColor Cyan