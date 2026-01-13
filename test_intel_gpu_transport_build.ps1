# Test script for Intel GPU transport build (PowerShell)

$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Intel GPU Transport Build Test" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Clean previous build
Write-Host ""
Write-Host "Step 1: Cleaning previous build..." -ForegroundColor Yellow
if (Test-Path "build") {
    Remove-Item -Recurse -Force "build"
}
python setup.py clean --all 2>$null

# Set environment variables for Intel GPU build
Write-Host ""
Write-Host "Step 2: Setting environment variables..." -ForegroundColor Yellow
$env:USE_INTEL_GPU = "1"
$env:USE_XCCL = "ON"
$env:USE_TRANSPORT = "ON"
$env:USE_NCCL = "OFF"
$env:USE_NCCLX = "OFF"
$env:USE_GLOO = "OFF"

Write-Host "  USE_INTEL_GPU=$env:USE_INTEL_GPU" -ForegroundColor Gray
Write-Host "  USE_XCCL=$env:USE_XCCL" -ForegroundColor Gray
Write-Host "  USE_TRANSPORT=$env:USE_TRANSPORT" -ForegroundColor Gray
Write-Host "  USE_NCCL=$env:USE_NCCL" -ForegroundColor Gray
Write-Host "  USE_NCCLX=$env:USE_NCCLX" -ForegroundColor Gray
Write-Host "  USE_GLOO=$env:USE_GLOO" -ForegroundColor Gray

# Optional: Set Level Zero directory if not in standard location
if ($env:LEVEL_ZERO_DIR) {
    Write-Host "  LEVEL_ZERO_DIR=$env:LEVEL_ZERO_DIR" -ForegroundColor Gray
}

# Build
Write-Host ""
Write-Host "Step 3: Building transport layer..." -ForegroundColor Yellow
$buildOutput = pip install --no-build-isolation -v -e . 2>&1 | Tee-Object -FilePath "build_log.txt"

# Check for success
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "✅ Build succeeded!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Checking for excluded files in build..." -ForegroundColor Yellow
    
    # Verify that CUDA-dependent files were excluded
    $logContent = Get-Content "build_log.txt" -Raw
    
    if ($logContent -match "AllReduceDirect\.cc") {
        Write-Host "⚠️  Warning: AllReduceDirect.cc was included in build" -ForegroundColor Yellow
    } else {
        Write-Host "✅ AllReduceDirect.cc was correctly excluded" -ForegroundColor Green
    }
    
    if ($logContent -match "AllGatherDirect\.cc") {
        Write-Host "⚠️  Warning: AllGatherDirect.cc was included in build" -ForegroundColor Yellow
    } else {
        Write-Host "✅ AllGatherDirect.cc was correctly excluded" -ForegroundColor Green
    }
    
    if ($logContent -match "AllToAllImpl\.cc") {
        Write-Host "⚠️  Warning: AllToAllImpl.cc was included in build" -ForegroundColor Yellow
    } else {
        Write-Host "✅ AllToAllImpl.cc was correctly excluded" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Build artifacts:" -ForegroundColor Yellow
    Get-ChildItem -Path "build" -Recurse -Include *.pyd,*.dll,*.lib -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  $($_.FullName)" -ForegroundColor Gray }
    
} else {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host "❌ Build failed!" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check build_log.txt for details" -ForegroundColor Yellow
    exit 1
}

