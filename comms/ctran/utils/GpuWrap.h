// Copyright (c) Meta Platforms, Inc. and affiliates.
// GPU abstraction layer for ctran - supports CUDA, HIP, and SYCL

#pragma once

#include "comms/utils/commSpecs.h"

// Detect GPU backend
#if defined(__HIP_PLATFORM_AMD__) || defined(__HIPCC__)
    #define CTRAN_USE_HIP
    #include <cuda.h>
    #include <cuda_runtime.h>
#elif defined(__SYCL_DEVICE_ONLY__) || defined(USE_INTEL_GPU) || defined(USE_SYCL)
    #define CTRAN_USE_SYCL
    // SYCL headers will be included separately where needed
    // to avoid polluting the namespace

    // Provide stub CUDA runtime functions for SYCL
    // These are no-ops for SYCL since PyTorch manages device context
    inline int cudaGetDevice(int* device) {
        if (device) *device = 0;  // Default to device 0
        return 0;  // cudaSuccess
    }

    inline int cudaSetDevice(int device) {
        (void)device;  // Unused
        return 0;  // cudaSuccess
    }

    // Define CUDA error codes for compatibility
    #define cudaSuccess 0
    #define cudaErrorInvalidValue 1

    // Define CUDA driver API types for compatibility
    typedef unsigned long long CUdeviceptr;
    typedef int CUdevice;
    typedef int CUresult;
    #define CUDA_SUCCESS 0

    // Stub CUDA driver API functions
    inline CUresult cuMemGetAddressRange(CUdeviceptr* pbase, size_t* psize, CUdeviceptr dptr) {
        (void)pbase; (void)psize; (void)dptr;
        return CUDA_SUCCESS;
    }

    inline CUresult cuGetErrorString(CUresult error, const char** pStr) {
        (void)error;
        if (pStr) *pStr = "SYCL stub - no error";
        return CUDA_SUCCESS;
    }
#else
    #define CTRAN_USE_CUDA
    #include <cuda.h>
    #include <cuda_runtime.h>
#endif

// CUDA error checking macros
// For SYCL, these are mostly no-ops since we don't have CUDA errors
#ifdef CTRAN_USE_SYCL
    #define FB_CUDACHECK(cmd) \
        do { \
            (void)(cmd); \
        } while (0)

    #define FB_CUDACHECKIGNORE(cmd) \
        do { \
            (void)(cmd); \
        } while (0)

    #define FB_CUDACHECKTHROW(cmd) \
        do { \
            (void)(cmd); \
        } while (0)

    #define FB_CUCHECK(cmd) \
        do { \
            (void)(cmd); \
        } while (0)

    #define FB_CUCHECKTHROW(cmd) \
        do { \
            (void)(cmd); \
        } while (0)

    #define FB_COMMCHECKTHROW(cmd) \
        do { \
            commResult_t _res = (cmd); \
            if (_res != commSuccess) { \
                throw std::runtime_error("COMM check failed"); \
            } \
        } while (0)
#else
    // For CUDA/HIP, include the actual CudaWrap.h
    #include "comms/ctran/utils/CudaWrap.h"
#endif

namespace ctran::utils {

// GPU library initialization
// This function initializes the GPU runtime library (CUDA/HIP/SYCL)
commResult_t commGpuLibraryInit();

// Check if GPU library is initialized
bool isCommGpuLibraryInited();

// DMA-BUF support detection
commResult_t dmaBufDriverSupport(int gpuDev);

// Get DMA-BUF file descriptor for a memory region
// Returns -1 if not supported
int getCuMemDmaBufFd(
    const void* buf,
    const size_t len,
    bool dataDirectPci = false);

// GPU Direct RDMA support check
bool gpuDirectRdmaWithCudaVmmSupported(
    const int gpuDev);

// CuMem system support
bool getCuMemSysSupported();
bool isCuMemSupported();

} // namespace ctran::utils

