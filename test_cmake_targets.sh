#!/bin/bash
# Test script to verify CMake modern targets configuration

set -e

echo "=========================================="
echo "Testing CMake Modern Targets Configuration"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if CONDA_PREFIX is set
if [ -z "$CONDA_PREFIX" ]; then
    print_error "CONDA_PREFIX is not set. Please activate your conda environment."
    exit 1
else
    print_success "CONDA_PREFIX is set to: $CONDA_PREFIX"
fi

# Create a temporary build directory for testing
TEST_BUILD_DIR="build_test_cmake_targets"
rm -rf "$TEST_BUILD_DIR"
mkdir -p "$TEST_BUILD_DIR"

print_info "Testing CMake configuration in: $TEST_BUILD_DIR"

# Test 1: Configure with USE_SYSTEM_LIBS=1
echo ""
echo "Test 1: Configuring with USE_SYSTEM_LIBS=1"
echo "----------------------------------------"
export USE_SYSTEM_LIBS=1

if cmake -B "$TEST_BUILD_DIR" -S . \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    -DUSE_NCCL=OFF \
    -DUSE_NCCLX=OFF \
    -DUSE_GLOO=ON \
    -DUSE_TRANSPORT=OFF \
    -DUSE_RCCL=OFF \
    -DUSE_RCCLX=OFF \
    -DUSE_XCCL=OFF 2>&1 | tee "$TEST_BUILD_DIR/configure.log"; then
    print_success "CMake configuration succeeded with USE_SYSTEM_LIBS=1"
else
    print_error "CMake configuration failed with USE_SYSTEM_LIBS=1"
    exit 1
fi

# Check if CMake found the packages
echo ""
echo "Checking for package detection:"
echo "----------------------------------------"

if grep -q "Found glog" "$TEST_BUILD_DIR/configure.log" 2>/dev/null; then
    print_success "glog package detected"
else
    print_info "glog package not found (will use fallback)"
fi

if grep -q "Found gflags" "$TEST_BUILD_DIR/configure.log" 2>/dev/null; then
    print_success "gflags package detected"
else
    print_info "gflags package not found (will use fallback)"
fi

if grep -q "Found fmt" "$TEST_BUILD_DIR/configure.log" 2>/dev/null; then
    print_success "fmt package detected"
else
    print_info "fmt package not found (will use fallback)"
fi

# Test 2: Configure with USE_SYSTEM_LIBS=0 (static linking)
echo ""
echo "Test 2: Configuring with USE_SYSTEM_LIBS=0 (static linking)"
echo "----------------------------------------"
rm -rf "$TEST_BUILD_DIR"
mkdir -p "$TEST_BUILD_DIR"
unset USE_SYSTEM_LIBS

if cmake -B "$TEST_BUILD_DIR" -S . \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    -DUSE_NCCL=OFF \
    -DUSE_NCCLX=OFF \
    -DUSE_GLOO=ON \
    -DUSE_TRANSPORT=OFF \
    -DUSE_RCCL=OFF \
    -DUSE_RCCLX=OFF \
    -DUSE_XCCL=OFF 2>&1 | tee "$TEST_BUILD_DIR/configure_static.log"; then
    print_success "CMake configuration succeeded with static linking"
else
    print_error "CMake configuration failed with static linking"
    exit 1
fi

# Cleanup
echo ""
echo "Cleaning up test build directory..."
rm -rf "$TEST_BUILD_DIR"

echo ""
echo "=========================================="
print_success "All CMake configuration tests passed!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Review the changes in CMakeLists.txt files"
echo "2. Build the project with: cmake -B build -S . && cmake --build build"
echo "3. Run your actual tests to verify functionality"

