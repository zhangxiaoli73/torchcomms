#!/bin/bash
# Diagnostic script to check dependency installation in conda environment

set +e  # Don't exit on error

echo "=========================================="
echo "Dependency Diagnostic Tool"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check CONDA_PREFIX
print_header "Conda Environment"
if [ -z "$CONDA_PREFIX" ]; then
    print_error "CONDA_PREFIX is not set!"
    echo "Please activate your conda environment first."
    exit 1
else
    print_success "CONDA_PREFIX: $CONDA_PREFIX"
fi

# Check directory structure
print_header "Directory Structure"
for dir in lib include share lib/pkgconfig lib/cmake; do
    if [ -d "$CONDA_PREFIX/$dir" ]; then
        print_success "$CONDA_PREFIX/$dir exists"
    else
        print_error "$CONDA_PREFIX/$dir does NOT exist"
    fi
done

# Check for glog
print_header "glog Installation"
echo "Checking for glog files..."

# Check library files
if [ -f "$CONDA_PREFIX/lib/libglog.so" ]; then
    print_success "Found shared library: $CONDA_PREFIX/lib/libglog.so"
    ls -lh "$CONDA_PREFIX/lib/libglog.so"*
elif [ -f "$CONDA_PREFIX/lib/libglog.a" ]; then
    print_success "Found static library: $CONDA_PREFIX/lib/libglog.a"
    ls -lh "$CONDA_PREFIX/lib/libglog.a"
else
    print_error "glog library NOT found"
fi

# Check header files
if [ -d "$CONDA_PREFIX/include/glog" ]; then
    print_success "Found glog headers: $CONDA_PREFIX/include/glog"
    ls "$CONDA_PREFIX/include/glog" | head -5
else
    print_error "glog headers NOT found"
fi

# Check CMake config files
if [ -d "$CONDA_PREFIX/lib/cmake/glog" ]; then
    print_success "Found glog CMake config: $CONDA_PREFIX/lib/cmake/glog"
    ls "$CONDA_PREFIX/lib/cmake/glog"
else
    print_error "glog CMake config NOT found"
    echo "Searching for glog CMake files..."
    find "$CONDA_PREFIX" -name "*glog*Config.cmake" -o -name "*glog*-config.cmake" 2>/dev/null || echo "No CMake config files found"
fi

# Check pkg-config files
if [ -f "$CONDA_PREFIX/lib/pkgconfig/libglog.pc" ]; then
    print_success "Found glog pkg-config: $CONDA_PREFIX/lib/pkgconfig/libglog.pc"
    cat "$CONDA_PREFIX/lib/pkgconfig/libglog.pc"
else
    print_error "glog pkg-config NOT found"
fi

# Check for gflags
print_header "gflags Installation"
echo "Checking for gflags files..."

if [ -f "$CONDA_PREFIX/lib/libgflags.so" ] || [ -f "$CONDA_PREFIX/lib/libgflags.a" ]; then
    print_success "Found gflags library"
    ls -lh "$CONDA_PREFIX/lib/libgflags"* 2>/dev/null | head -3
else
    print_error "gflags library NOT found"
fi

if [ -d "$CONDA_PREFIX/lib/cmake/gflags" ]; then
    print_success "Found gflags CMake config: $CONDA_PREFIX/lib/cmake/gflags"
    ls "$CONDA_PREFIX/lib/cmake/gflags"
else
    print_error "gflags CMake config NOT found"
fi

# Check for fmt
print_header "fmt Installation"
echo "Checking for fmt files..."

if [ -f "$CONDA_PREFIX/lib/libfmt.so" ] || [ -f "$CONDA_PREFIX/lib/libfmt.a" ]; then
    print_success "Found fmt library"
    ls -lh "$CONDA_PREFIX/lib/libfmt"* 2>/dev/null | head -3
else
    print_error "fmt library NOT found"
fi

if [ -d "$CONDA_PREFIX/lib/cmake/fmt" ]; then
    print_success "Found fmt CMake config: $CONDA_PREFIX/lib/cmake/fmt"
    ls "$CONDA_PREFIX/lib/cmake/fmt"
else
    print_error "fmt CMake config NOT found"
fi

# Check conda packages
print_header "Installed Conda Packages"
echo "Checking for glog, gflags, fmt in conda..."
conda list | grep -E "glog|gflags|fmt" || echo "No matching packages found"

# Recommendations
print_header "Recommendations"
echo ""

# Check if packages need to be installed
NEEDS_INSTALL=0

if [ ! -f "$CONDA_PREFIX/lib/libglog.so" ] && [ ! -f "$CONDA_PREFIX/lib/libglog.a" ]; then
    print_info "Install glog: conda install -c conda-forge glog"
    NEEDS_INSTALL=1
fi

if [ ! -f "$CONDA_PREFIX/lib/libgflags.so" ] && [ ! -f "$CONDA_PREFIX/lib/libgflags.a" ]; then
    print_info "Install gflags: conda install -c conda-forge gflags"
    NEEDS_INSTALL=1
fi

if [ ! -f "$CONDA_PREFIX/lib/libfmt.so" ] && [ ! -f "$CONDA_PREFIX/lib/libfmt.a" ]; then
    print_info "Install fmt: conda install -c conda-forge fmt"
    NEEDS_INSTALL=1
fi

if [ $NEEDS_INSTALL -eq 0 ]; then
    print_success "All required libraries are installed"
    echo ""
    echo "If CMake still can't find them, try:"
    echo "  export CMAKE_PREFIX_PATH=\$CONDA_PREFIX:\$CMAKE_PREFIX_PATH"
    echo "  cmake -B build -S . -DCMAKE_FIND_DEBUG_MODE=ON"
fi

echo ""
echo "=========================================="

