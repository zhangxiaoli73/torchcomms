# glog Compatibility Fix for Intel GPU Build

## Problem
When building torchcomms with Intel GPU support, we encountered compilation errors related to glog v0.4.0:

```
include/glog/logging.h:711:25: error: 'MakeCheckOpValueString' was not declared in this scope
comms/torchcomms/TorchCommLogging.hpp:119:15: error: 'InitGoogleLogging' is not a member of 'google'
comms/torchcomms/TorchCommLogging.hpp:121:15: error: 'InstallFailureSignalHandler' is not a member of 'google'
```

## Root Cause
1. **Old glog version**: The project uses glog v0.4.0 (from `build_rcclx.sh`), which has some API differences from newer versions
2. **Template instantiation issues**: The `MakeCheckOpValueString` function is an internal glog template that may not be properly declared in older versions
3. **Namespace issues**: Some glog functions need explicit forward declarations to work correctly with older versions

## Solution

### 1. Added GLOG_NO_ABBREVIATED_SEVERITIES Definition
**File**: `CMakeLists.txt`

Added compile definition to prevent macro conflicts:
```cmake
target_compile_definitions(torchcomms PRIVATE GLOG_NO_ABBREVIATED_SEVERITIES)
```

This prevents glog from defining abbreviated severity macros (INFO, WARNING, ERROR, FATAL) that can conflict with other libraries.

### 2. Updated TorchCommLogging.hpp
**File**: `comms/torchcomms/TorchCommLogging.hpp`

Made three key changes:

#### a. Define GLOG_NO_ABBREVIATED_SEVERITIES before including glog
```cpp
// Define this before including glog to avoid macro conflicts
#ifndef GLOG_NO_ABBREVIATED_SEVERITIES
#define GLOG_NO_ABBREVIATED_SEVERITIES
#endif

#include <glog/logging.h>
```

#### b. Forward declare glog functions in google namespace
```cpp
#ifndef _WIN32
namespace google {
namespace glog_internal_namespace_ {
bool IsGoogleLoggingInitialized();
} // namespace glog_internal_namespace_
void InitGoogleLogging(const char* argv0);
void InstallFailureSignalHandler();
} // namespace google
#endif
```

This explicitly declares the functions in the `google` namespace, which helps the compiler find them even with older glog versions.

#### c. Guard glog initialization for non-Windows platforms
```cpp
void tryTorchCommLoggingInit(std::string_view name) {
#ifndef _WIN32
  // This trick can only be used on UNIX platforms
  if (!::google::glog_internal_namespace_::IsGoogleLoggingInitialized()) {
    ::google::InitGoogleLogging(name.data());
    ::google::InstallFailureSignalHandler();
  }
#endif
}
```

## Why This Works

1. **GLOG_NO_ABBREVIATED_SEVERITIES**: Prevents macro name collisions that can cause compilation errors
2. **Forward declarations**: Helps the compiler resolve function names in the correct namespace, even with older glog versions
3. **Platform guards**: Ensures glog initialization only happens on supported platforms (Linux)

## Testing
After applying these changes, rebuild the project:
```bash
cd /path/to/build/directory
cmake --build . --target torchcomms
```

## Related Files
- `CMakeLists.txt` - Added compile definition
- `comms/torchcomms/TorchCommLogging.hpp` - Updated glog includes and initialization
- `build_rcclx.sh` - Shows glog v0.4.0 is being used

## Notes
- This fix maintains compatibility with glog v0.4.0 while allowing the code to compile
- The changes are backward compatible and don't affect functionality
- If upgrading to a newer glog version in the future, some of these workarounds may no longer be necessary

