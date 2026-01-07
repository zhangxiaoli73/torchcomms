#!/bin/bash
# Check if CMake config files exist for installed packages

set +e

echo "=========================================="
echo "Checking CMake Config Files"
echo "=========================================="

if [ -z "$CONDA_PREFIX" ]; then
    echo "Error: CONDA_PREFIX is not set"
    exit 1
fi

echo "CONDA_PREFIX: $CONDA_PREFIX"
echo ""

# Function to check for CMake config files
check_cmake_config() {
    local package=$1
    echo "Checking $package..."
    
    # Check common locations
    local found=0
    
    # Location 1: lib/cmake/<package>
    if [ -d "$CONDA_PREFIX/lib/cmake/$package" ]; then
        echo "  ✓ Found: $CONDA_PREFIX/lib/cmake/$package"
        ls "$CONDA_PREFIX/lib/cmake/$package"
        found=1
    fi
    
    # Location 2: lib64/cmake/<package>
    if [ -d "$CONDA_PREFIX/lib64/cmake/$package" ]; then
        echo "  ✓ Found: $CONDA_PREFIX/lib64/cmake/$package"
        ls "$CONDA_PREFIX/lib64/cmake/$package"
        found=1
    fi
    
    # Location 3: share/cmake/<package>
    if [ -d "$CONDA_PREFIX/share/cmake/$package" ]; then
        echo "  ✓ Found: $CONDA_PREFIX/share/cmake/$package"
        ls "$CONDA_PREFIX/share/cmake/$package"
        found=1
    fi
    
    # Search for any *Config.cmake or *-config.cmake files
    local config_files=$(find "$CONDA_PREFIX" -name "${package}Config.cmake" -o -name "${package}-config.cmake" 2>/dev/null)
    if [ -n "$config_files" ]; then
        echo "  ✓ Found config files:"
        echo "$config_files"
        found=1
    fi
    
    if [ $found -eq 0 ]; then
        echo "  ✗ No CMake config files found for $package"
        echo "  Checking for library files..."
        ls -lh "$CONDA_PREFIX/lib/lib${package}"* 2>/dev/null || echo "    No library files found"
    fi
    
    echo ""
}

# Check each package
check_cmake_config "glog"
check_cmake_config "gflags"
check_cmake_config "fmt"

# Also check with different case/naming
echo "Searching for any glog-related CMake files..."
find "$CONDA_PREFIX" -type f -name "*glog*.cmake" 2>/dev/null | head -10

echo ""
echo "Searching for any gflags-related CMake files..."
find "$CONDA_PREFIX" -type f -name "*gflags*.cmake" 2>/dev/null | head -10

echo ""
echo "Searching for any fmt-related CMake files..."
find "$CONDA_PREFIX" -type f -name "*fmt*.cmake" 2>/dev/null | head -10

echo ""
echo "=========================================="
echo "Library files check:"
echo "=========================================="
ls -lh "$CONDA_PREFIX/lib/libglog"* 2>/dev/null
ls -lh "$CONDA_PREFIX/lib/libgflags"* 2>/dev/null
ls -lh "$CONDA_PREFIX/lib/libfmt"* 2>/dev/null

echo ""
echo "=========================================="
echo "Header files check:"
echo "=========================================="
ls -d "$CONDA_PREFIX/include/glog" 2>/dev/null && echo "✓ glog headers found"
ls -d "$CONDA_PREFIX/include/gflags" 2>/dev/null && echo "✓ gflags headers found"
ls -d "$CONDA_PREFIX/include/fmt" 2>/dev/null && echo "✓ fmt headers found"

