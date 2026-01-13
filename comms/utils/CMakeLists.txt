# Copyright (c) Meta Platforms, Inc. and affiliates.

# Only require CUDA if not using Intel GPU
if(NOT USE_INTEL_GPU)
    find_package(CUDA REQUIRED)
endif()

file(GLOB_RECURSE UTILS_SOURCES
    "*.cc"
)
list(FILTER UTILS_SOURCES EXCLUDE REGEX ".*/tests/.*")

# Exclude CUDA-specific files when building for Intel GPU
if(USE_INTEL_GPU)
    list(FILTER UTILS_SOURCES EXCLUDE REGEX ".*CudaRAII\\.cc$")
    list(FILTER UTILS_SOURCES EXCLUDE REGEX ".*CudaEventPool\\.cc$")
    list(FILTER UTILS_SOURCES EXCLUDE REGEX ".*CudaWaitEvent\\.cc$")
    list(FILTER UTILS_SOURCES EXCLUDE REGEX ".*CPUWaitEvent\\.cc$")
    message(STATUS "Excluding CUDA-specific files from utils for Intel GPU build")
endif()

add_library(utils OBJECT
    ${UTILS_SOURCES}
)

target_compile_features(utils PRIVATE cxx_std_20)
target_compile_options(utils PRIVATE
    -fPIC
)
target_include_directories(utils PUBLIC
    ${ROOT}
    ${CONDA_INCLUDE}
)

# Try to find folly headers
if(DEFINED ENV{CONDA_PREFIX})
    find_path(FOLLY_INCLUDE_DIR
        NAMES folly/dynamic.h
        PATHS
            $ENV{CONDA_PREFIX}/include
            ${TORCH_INSTALL_PREFIX}/include
            ${TORCH_INSTALL_PREFIX}/../include
        NO_DEFAULT_PATH
    )
    if(FOLLY_INCLUDE_DIR)
        message(STATUS "Found folly headers for utils: ${FOLLY_INCLUDE_DIR}")
        target_include_directories(utils PUBLIC ${FOLLY_INCLUDE_DIR})
    else()
        message(WARNING "folly headers not found, some features may not compile")
    endif()
endif()

# Add CUDA include directories only if using CUDA
if(NOT USE_INTEL_GPU)
    target_include_directories(utils PUBLIC ${CUDA_INCLUDE_DIRS})
endif()
