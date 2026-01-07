#!/bin/bash
# Clean and rebuild script for torchcomms with Intel GPU support

set -e  # Exit on error

echo "=========================================="
echo "Cleaning previous build..."
echo "=========================================="

# Remove build directory if it exists
if [ -d "build" ]; then
    echo "Removing build directory..."
    rm -rf build
    echo "Build directory removed."
else
    echo "No build directory found."
fi

echo ""
echo "=========================================="
echo "Creating new build directory..."
echo "=========================================="
mkdir -p build
cd build

echo ""
echo "=========================================="
echo "Running CMake configuration..."
echo "=========================================="

# Configure CMake with Intel GPU support
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DUSE_INTEL_GPU=ON \
  -DUSE_XCCL=ON

echo ""
echo "=========================================="
echo "Building torchcomms..."
echo "=========================================="

# Build with all available cores
cmake --build . -j$(nproc)

echo ""
echo "=========================================="
echo "Build completed successfully!"
echo "=========================================="

