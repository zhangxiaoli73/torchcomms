#!/bin/bash
# Upgrade glog to a compatible version

set -e

echo "=========================================="
echo "Checking current glog version..."
echo "=========================================="

# Check current version
echo "Current glog version:"
conda list | grep glog || echo "glog not installed via conda"

echo ""
echo "=========================================="
echo "Upgrading glog to v0.7.0..."
echo "=========================================="

# Remove old version
echo "Removing old glog version..."
conda remove glog -y || true

# Install new version
echo "Installing glog v0.7.0..."
conda install conda-forge::glog=0.7.0 -y

echo ""
echo "=========================================="
echo "Verifying installation..."
echo "=========================================="

# Verify installation
echo "New glog version:"
conda list | grep glog

echo ""
echo "glog library files:"
ls -lh $CONDA_PREFIX/lib/libglog* 2>/dev/null || echo "Warning: glog libraries not found"

echo ""
echo "glog header files:"
ls -lh $CONDA_PREFIX/include/glog/ 2>/dev/null || echo "Warning: glog headers not found"

echo ""
echo "=========================================="
echo "glog upgrade complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Clean previous build: pip uninstall -y torchcomms && rm -rf build/ dist/ *.egg-info"
echo "2. Rebuild: ./rebuild.sh"

