// Copyright (c) Meta Platforms, Inc. and affiliates.
// Level Zero wrapper implementation for Intel GPU DMA-BUF support

#include "comms/ctran/utils/LevelZeroWrap.h"

#ifdef CTRAN_USE_SYCL

#include <mutex>
#include <unistd.h>
#include <fcntl.h>

namespace ctran::utils {

// Singleton instance
LevelZeroContext& LevelZeroContext::getInstance() {
  static LevelZeroContext instance;
  return instance;
}

LevelZeroContext::~LevelZeroContext() {
  if (context_) {
    zeContextDestroy(context_);
  }
}

commResult_t LevelZeroContext::init() {
  if (initialized_) {
    return commSuccess;
  }

  // Initialize Level Zero
  ZE_CHECK(zeInit(ZE_INIT_FLAG_GPU_ONLY));

  // Discover all driver instances
  uint32_t driverCount = 0;
  ZE_CHECK(zeDriverGet(&driverCount, nullptr));
  
  if (driverCount == 0) {
    CLOGF(ERR, "No Level Zero drivers found");
    return commSystemError;
  }

  std::vector<ze_driver_handle_t> drivers(driverCount);
  ZE_CHECK(zeDriverGet(&driverCount, drivers.data()));
  
  // Use the first driver
  driver_ = drivers[0];

  // Discover devices
  uint32_t deviceCount = 0;
  ZE_CHECK(zeDeviceGet(driver_, &deviceCount, nullptr));
  
  if (deviceCount == 0) {
    CLOGF(ERR, "No Level Zero devices found");
    return commSystemError;
  }

  devices_.resize(deviceCount);
  ZE_CHECK(zeDeviceGet(driver_, &deviceCount, devices_.data()));
  deviceCount_ = deviceCount;

  // Create context
  ze_context_desc_t contextDesc = {
      ZE_STRUCTURE_TYPE_CONTEXT_DESC,
      nullptr,
      0};
  ZE_CHECK(zeContextCreate(driver_, &contextDesc, &context_));

  initialized_ = true;
  CLOGF_SUBSYS(INFO, INIT, "Level Zero initialized: {} devices found", deviceCount_);
  
  return commSuccess;
}

ze_device_handle_t LevelZeroContext::getDevice(int deviceId) const {
  if (deviceId < 0 || deviceId >= deviceCount_) {
    CLOGF(ERR, "Invalid device ID: {}", deviceId);
    return nullptr;
  }
  return devices_[deviceId];
}

// Get DMA-BUF file descriptor for a memory allocation
int getLevelZeroDmaBufFd(const void* ptr, size_t size, int deviceId) {
  auto& ctx = LevelZeroContext::getInstance();

  if (!ctx.isInitialized()) {
    CLOGF(ERR, "Level Zero not initialized");
    return -1;
  }

  ze_device_handle_t device = ctx.getDevice(deviceId);
  if (!device) {
    return -1;
  }

  // Export as DMA-BUF file descriptor using zeMemGetAllocProperties
  // According to Level Zero spec, ze_external_memory_export_fd_t should be
  // passed via pNext chain of ze_memory_allocation_properties_t

  ze_external_memory_export_fd_t exportFd = {
      ZE_STRUCTURE_TYPE_EXTERNAL_MEMORY_EXPORT_FD,
      nullptr,
      ZE_EXTERNAL_MEMORY_TYPE_FLAG_DMA_BUF,
      -1};  // fd will be filled by the driver

  ze_memory_allocation_properties_t memProps = {
      ZE_STRUCTURE_TYPE_MEMORY_ALLOCATION_PROPERTIES,
      &exportFd};  // Chain the export descriptor

  ze_device_handle_t allocDevice = nullptr;

  ze_result_t result = zeMemGetAllocProperties(
      ctx.getContext(),
      ptr,
      &memProps,
      &allocDevice);

  if (result != ZE_RESULT_SUCCESS) {
    CLOGF(ERR, "Failed to export DMA-BUF fd via zeMemGetAllocProperties: {}",
          static_cast<int>(result));
    return -1;
  }

  if (exportFd.fd < 0) {
    CLOGF(ERR, "Invalid file descriptor returned: {}", exportFd.fd);
    return -1;
  }

  CLOGF_TRACE(ALLOC, "Exported DMA-BUF fd={} for ptr={}, size={}, device={}",
              exportFd.fd, ptr, size, deviceId);

  return exportFd.fd;
}

// Check if DMA-BUF is supported
commResult_t levelZeroDmaBufSupport(int deviceId) {
  auto& ctx = LevelZeroContext::getInstance();

  if (!ctx.isInitialized()) {
    if (levelZeroLibraryInit() != commSuccess) {
      return commSystemError;
    }
  }

  ze_device_handle_t device = ctx.getDevice(deviceId);
  if (!device) {
    return commSystemError;
  }

  // Query device properties for external memory support
  ze_device_external_memory_properties_t extMemProps = {
      ZE_STRUCTURE_TYPE_DEVICE_EXTERNAL_MEMORY_PROPERTIES,
      nullptr};

  ze_result_t result = zeDeviceGetExternalMemoryProperties(device, &extMemProps);

  if (result != ZE_RESULT_SUCCESS) {
    CLOGF(WARN, "Failed to query external memory properties: {}", static_cast<int>(result));
    return commInternalError;
  }

  // Check if DMA-BUF is supported
  if (extMemProps.memoryAllocationExportTypes & ZE_EXTERNAL_MEMORY_TYPE_FLAG_DMA_BUF) {
    CLOGF_SUBSYS(INFO, INIT, "DMA-BUF is supported on Intel GPU device {}", deviceId);
    return commSuccess;
  }

  CLOGF(WARN, "DMA-BUF not supported on Intel GPU device {}", deviceId);
  return commInternalError;
}

// Check if GPU Direct RDMA is supported
bool levelZeroGpuDirectRdmaSupported(int deviceId) {
  // For Intel GPUs, GPU Direct RDMA support depends on:
  // 1. DMA-BUF support (checked above)
  // 2. Kernel driver support (i915/xe with peer memory module)
  // 3. NIC support (Mellanox with peer direct)

  if (levelZeroDmaBufSupport(deviceId) != commSuccess) {
    return false;
  }

  // Check for Intel GPU peer memory kernel module
  // Similar to nv_peer_mem for NVIDIA GPUs
  if (access("/sys/module/i915_peermem", F_OK) == 0 ||
      access("/sys/module/xe_peermem", F_OK) == 0) {
    CLOGF_SUBSYS(INFO, INIT, "Intel GPU peer memory module detected");
    return true;
  }

  CLOGF(WARN, "Intel GPU peer memory module not found. GPU Direct RDMA may not work.");
  return false;
}

// Initialize Level Zero library
static std::once_flag levelZeroInitFlag;
static commResult_t levelZeroInitResult = commSystemError;

commResult_t levelZeroLibraryInit() {
  std::call_once(levelZeroInitFlag, []() {
    auto& ctx = LevelZeroContext::getInstance();
    levelZeroInitResult = ctx.init();
  });
  return levelZeroInitResult;
}

// Check if Level Zero library is initialized
bool isLevelZeroLibraryInited() {
  return levelZeroInitResult == commSuccess;
}

} // namespace ctran::utils

#endif // CTRAN_USE_SYCL

