#!/bin/bash
# Script to install required dependencies in conda environment

set -e

echo "=========================================="
echo "Installing Dependencies for torchcomms"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
if [ -z "$CONDA_PREFIX" ]; then
    print_error "CONDA_PREFIX is not set!"
    echo "Please activate your conda environment first:"
    echo "  conda activate your-env-name"
    exit 1
fi

print_success "Using conda environment: $CONDA_PREFIX"
echo ""

# Function to check if a library exists
check_library() {
    local lib_name=$1
    if [ -f "$CONDA_PREFIX/lib/lib${lib_name}.so" ] || [ -f "$CONDA_PREFIX/lib/lib${lib_name}.a" ]; then
        return 0
    else
        return 1
    fi
}

# Check and install glog
echo "Checking glog..."
if check_library "glog"; then
    print_success "glog is already installed"
else
    print_info "Installing glog..."
    conda install -y -c conda-forge glog
    if check_library "glog"; then
        print_success "glog installed successfully"
    else
        print_error "Failed to install glog"
    fi
fi

# Check and install gflags
echo ""
echo "Checking gflags..."
if check_library "gflags"; then
    print_success "gflags is already installed"
else
    print_info "Installing gflags..."
    conda install -y -c conda-forge gflags
    if check_library "gflags"; then
        print_success "gflags installed successfully"
    else
        print_error "Failed to install gflags"
    fi
fi

# Check and install fmt
echo ""
echo "Checking fmt..."
if check_library "fmt"; then
    print_success "fmt is already installed"
else
    print_info "Installing fmt..."
    conda install -y -c conda-forge fmt
    if check_library "fmt"; then
        print_success "fmt installed successfully"
    else
        print_error "Failed to install fmt"
    fi
fi

# Check and install other common dependencies
echo ""
echo "Checking other dependencies..."

# Boost
if [ -f "$CONDA_PREFIX/lib/libboost_system.so" ] || [ -f "$CONDA_PREFIX/lib/libboost_system.a" ]; then
    print_success "boost is already installed"
else
    print_info "Installing boost..."
    conda install -y -c conda-forge boost
fi

# folly (if using system libs)
if [ -f "$CONDA_PREFIX/lib/libfolly.so" ] || [ -f "$CONDA_PREFIX/lib/libfolly.a" ]; then
    print_success "folly is already installed"
else
    print_info "folly not found (this is OK if not using USE_SYSTEM_LIBS)"
fi

echo ""
echo "=========================================="
print_success "Dependency installation complete!"
echo "=========================================="
echo ""

# Show installed versions
echo "Installed package versions:"
conda list | grep -E "glog|gflags|fmt|boost" || echo "No matching packages found"

echo ""
echo "Next steps:"
echo "1. Verify installation: ./diagnose_dependencies.sh"
echo "2. Build the project:"
echo "   export USE_SYSTEM_LIBS=1"
echo "   cmake -B build -S ."
echo "   cmake --build build"

