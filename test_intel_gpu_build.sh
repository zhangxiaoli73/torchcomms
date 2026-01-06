#!/bin/bash
# Test script for building torchcomms with Intel GPU and RDMA Transport support

set -e  # Exit on error

echo "========================================="
echo "Testing Intel GPU + RDMA Transport Build"
echo "========================================="

# Check environment
echo ""
echo "Checking environment..."

if [ -z "$CCL_ROOT" ]; then
    echo "WARNING: CCL_ROOT not set. XCCL backend may not build."
else
    echo "CCL_ROOT: $CCL_ROOT"
fi

if [ -z "$LEVEL_ZERO_DIR" ]; then
    echo "WARNING: LEVEL_ZERO_DIR not set. Will search in standard paths."
else
    echo "LEVEL_ZERO_DIR: $LEVEL_ZERO_DIR"
fi

# Check for Level Zero headers
echo ""
echo "Checking for Level Zero..."
if [ -f "/usr/include/level_zero/ze_api.h" ] || [ -f "$LEVEL_ZERO_DIR/include/level_zero/ze_api.h" ]; then
    echo "✓ Level Zero headers found"
else
    echo "✗ Level Zero headers NOT found"
    echo "  Please install: sudo apt-get install level-zero-dev"
    exit 1
fi

# Check for Level Zero library
if ldconfig -p | grep -q libze_loader; then
    echo "✓ Level Zero library found"
else
    echo "✗ Level Zero library NOT found"
    echo "  Please install: sudo apt-get install level-zero"
    exit 1
fi

# Clean previous build
echo ""
echo "Cleaning previous build..."
rm -rf build_intel_gpu
mkdir -p build_intel_gpu
cd build_intel_gpu

# Configure with Intel GPU support
echo ""
echo "Configuring CMake with Intel GPU and Transport..."
export USE_INTEL_GPU=1

cmake .. \
    -DUSE_XCCL=ON \
    -DUSE_TRANSPORT=ON \
    -DUSE_NCCL=OFF \
    -DUSE_NCCLX=OFF \
    -DUSE_GLOO=OFF \
    -DUSE_RCCL=OFF \
    -DUSE_RCCLX=OFF \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DCMAKE_VERBOSE_MAKEFILE=ON

echo ""
echo "Building..."
make -j$(nproc) VERBOSE=1

echo ""
echo "========================================="
echo "Build completed successfully!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Test the build: cd build_intel_gpu && ctest"
echo "2. Install: pip install --no-build-isolation -v ."
echo "3. Run RDMA transport tests"
echo ""
echo "To enable GPU Direct RDMA, ensure:"
echo "  - Intel GPU peer memory kernel module is loaded"
echo "  - Mellanox OFED drivers are installed"
echo "  - IB devices are available: ibv_devices"

