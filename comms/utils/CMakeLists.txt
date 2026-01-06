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

# Add CUDA include directories only if using CUDA
if(NOT USE_INTEL_GPU)
    target_include_directories(utils PUBLIC ${CUDA_INCLUDE_DIRS})
endif()
