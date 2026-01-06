#!/bin/bash
# Test script for building RDMA Transport with Intel GPU/SYCL support

set -e  # Exit on error

echo "========================================="
echo "Testing RDMA Transport Build with SYCL"
echo "========================================="

# Clean previous build
rm -rf build_test_transport
mkdir -p build_test_transport
cd build_test_transport

# Configure with XCCL and Transport enabled
echo ""
echo "Configuring CMake with XCCL and Transport..."
cmake .. \
    -DUSE_XCCL=ON \
    -DUSE_TRANSPORT=ON \
    -DUSE_NCCL=OFF \
    -DUSE_NCCLX=OFF \
    -DUSE_GLOO=OFF \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

# Build only the transport module
echo ""
echo "Building transport module..."
cmake --build . --target rdma_transport -j$(nproc)

# Check if the library was built
if [ -f "comms/torchcomms/transport/librdma_transport.so" ]; then
    echo ""
    echo "========================================="
    echo "SUCCESS: Transport library built!"
    echo "========================================="
    ls -lh comms/torchcomms/transport/librdma_transport.so
    
    # Show symbols
    echo ""
    echo "Checking exported symbols..."
    nm -D comms/torchcomms/transport/librdma_transport.so | grep -i "rdma\|transport" | head -20
else
    echo ""
    echo "========================================="
    echo "FAILED: Transport library not found!"
    echo "========================================="
    exit 1
fi

cd ..
echo ""
echo "Build test completed successfully!"

