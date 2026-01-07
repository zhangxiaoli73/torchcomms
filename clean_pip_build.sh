#!/bin/bash
# Clean pip build artifacts and rebuild torchcomms

set -e  # Exit on error

echo "=========================================="
echo "Cleaning pip build artifacts..."
echo "=========================================="

# Uninstall existing torchcomms package
echo "Uninstalling existing torchcomms package..."
pip uninstall -y torchcomms || true

# Clean Python build artifacts
echo "Cleaning Python build artifacts..."
rm -rf build/
rm -rf dist/
rm -rf *.egg-info
rm -rf .eggs/
find . -type f -name '*.pyc' -delete
find . -type d -name '__pycache__' -delete
find . -type f -name '*.so' -delete
find . -type f -name '*.o' -delete

# Clean CMake cache files
echo "Cleaning CMake cache files..."
rm -rf CMakeFiles/
rm -f CMakeCache.txt
rm -f cmake_install.cmake
rm -f Makefile

# Clean pip cache for this package
echo "Cleaning pip cache..."
pip cache remove torchcomms || true

echo ""
echo "=========================================="
echo "Setting up environment..."
echo "=========================================="

# Set build environment variables
export USE_XCCL=ON
export USE_NCCL=OFF
export USE_NCCLX=OFF
export USE_TRANSPORT=ON
export USE_SYSTEM_LIBS=1
export TEST_BACKEND=xccl
export TEST_DEVICE=xpu
export GLOG_minloglevel=0
export GLOG_logtostderr=1

# Source Intel oneAPI environment
echo "Sourcing Intel oneAPI environment..."
source ~/intel/oneapi/setvars.sh
source ~/intel/oneapi/pti/0.13/env/vars.sh

echo ""
echo "=========================================="
echo "Building and installing torchcomms..."
echo "=========================================="

# Build and install with verbose output
pip install --no-build-isolation -v . 2>&1 | tee pip_build.log

echo ""
echo "=========================================="
echo "Build completed!"
echo "=========================================="
echo "Build log saved to: pip_build.log"
echo ""
echo "To verify installation:"
echo "  python -c 'import torchcomms; print(torchcomms.__version__)'"

