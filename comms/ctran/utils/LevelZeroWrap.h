// Copyright (c) Meta Platforms, Inc. and affiliates.
// Level Zero wrapper for Intel GPU DMA-BUF support

#pragma once

#ifdef CTRAN_USE_SYCL

#include <level_zero/ze_api.h>
#include <fmt/format.h>
#include <string>

#include "comms/utils/commSpecs.h"
#include "comms/utils/logger/LogUtils.h"

namespace ctran::utils {

// Level Zero error checking macro
#define ZE_CHECK(cmd)                                                          \
  do {                                                                         \
    ze_result_t err = cmd;                                                     \
    if (err != ZE_RESULT_SUCCESS) {                                            \
      CLOGF(ERR, "Level Zero failure: {} (error code: {})", #cmd,              \
            static_cast<int>(err));                                            \
      return commUnhandledCudaError;                                           \
    }                                                                          \
  } while (false)

#define ZE_CHECK_RETURN(cmd, ret)                                              \
  do {                                                                         \
    ze_result_t err = cmd;                                                     \
    if (err != ZE_RESULT_SUCCESS) {                                            \
      CLOGF(ERR, "Level Zero failure: {} (error code: {})", #cmd,              \
            static_cast<int>(err));                                            \
      return ret;                                                              \
    }                                                                          \
  } while (false)

// Level Zero context management
class LevelZeroContext {
 public:
  static LevelZeroContext& getInstance();
  
  commResult_t init();
  bool isInitialized() const { return initialized_; }
  
  ze_driver_handle_t getDriver() const { return driver_; }
  ze_device_handle_t getDevice(int deviceId) const;
  ze_context_handle_t getContext() const { return context_; }
  
  int getDeviceCount() const { return deviceCount_; }

 private:
  LevelZeroContext() = default;
  ~LevelZeroContext();
  
  bool initialized_ = false;
  ze_driver_handle_t driver_ = nullptr;
  ze_context_handle_t context_ = nullptr;
  std::vector<ze_device_handle_t> devices_;
  int deviceCount_ = 0;
};

// Get DMA-BUF file descriptor for a Level Zero memory allocation
// This is the Intel GPU equivalent of cuMemGetHandleForAddressRange
//
// IMPORTANT: The memory must have been allocated with ZE_EXTERNAL_MEMORY_TYPE_FLAG_DMA_BUF
// specified in ze_external_memory_export_desc_t during allocation.
//
// Usage:
//   ze_external_memory_export_desc_t exportDesc = {
//       ZE_STRUCTURE_TYPE_EXTERNAL_MEMORY_EXPORT_DESC,
//       nullptr,
//       ZE_EXTERNAL_MEMORY_TYPE_FLAG_DMA_BUF};
//   ze_device_mem_alloc_desc_t deviceDesc = {
//       ZE_STRUCTURE_TYPE_DEVICE_MEM_ALLOC_DESC,
//       &exportDesc,  // Chain export descriptor
//       ...};
//   zeMemAllocDevice(context, &deviceDesc, size, alignment, device, &ptr);
//
int getLevelZeroDmaBufFd(const void* ptr, size_t size, int deviceId);

// Check if DMA-BUF is supported on the given device
commResult_t levelZeroDmaBufSupport(int deviceId);

// Check if GPU Direct RDMA is supported
bool levelZeroGpuDirectRdmaSupported(int deviceId);

// Initialize Level Zero library
commResult_t levelZeroLibraryInit();

// Check if Level Zero library is initialized
bool isLevelZeroLibraryInited();

} // namespace ctran::utils

#endif // CTRAN_USE_SYCL

