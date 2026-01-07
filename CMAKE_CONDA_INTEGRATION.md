# CMake 与 Conda 环境集成指南

## 问题背景

当使用 conda 安装的依赖包（如 glog, gflags, fmt）时，可能会遇到以下问题：

1. **CMake CONFIG 文件缺失**: 某些 conda 包不提供 `*Config.cmake` 文件
2. **pkg-config 文件缺失**: `share/pkgconfig` 目录可能不存在
3. **CMake 找不到包**: 即使库文件存在，`find_package()` 也可能失败

## 解决方案

本项目采用了**三层回退机制**来确保依赖项能够被正确找到和链接：

### 第一层：尝试 CONFIG 模式

```cmake
find_package(glog CONFIG QUIET)
find_package(gflags CONFIG QUIET)
find_package(fmt CONFIG QUIET)
```

如果包提供了 CMake config 文件，这是最优方案。

### 第二层：手动创建 Imported Targets

如果 CONFIG 模式失败，CMake 会自动查找库文件和头文件，并创建 imported targets：

```cmake
if(NOT TARGET glog::glog AND DEFINED ENV{CONDA_PREFIX})
    find_library(GLOG_LIBRARY NAMES glog PATHS "$ENV{CONDA_PREFIX}/lib" NO_DEFAULT_PATH)
    find_path(GLOG_INCLUDE_DIR NAMES glog/logging.h PATHS "$ENV{CONDA_PREFIX}/include" NO_DEFAULT_PATH)
    
    if(GLOG_LIBRARY AND GLOG_INCLUDE_DIR)
        add_library(glog::glog UNKNOWN IMPORTED)
        set_target_properties(glog::glog PROPERTIES
            IMPORTED_LOCATION "${GLOG_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${GLOG_INCLUDE_DIR}"
        )
        message(STATUS "Created glog::glog imported target from: ${GLOG_LIBRARY}")
    endif()
endif()
```

这样即使没有 CMake config 文件，只要库文件存在，就能创建 `glog::glog` target。

### 第三层：传统链接方式

如果前两层都失败，代码会回退到传统的 `-lglog` 链接方式：

```cmake
if(TARGET glog::glog)
    target_link_libraries(torchcomms PRIVATE glog::glog)
else()
    target_link_directories(torchcomms PRIVATE ${CONDA_LIB})
    target_link_libraries(torchcomms PRIVATE "-lglog")
endif()
```

## 使用方法

### 1. 确认依赖已安装

```bash
# 激活 conda 环境
conda activate your-env

# 检查已安装的包
conda list | grep -E "glog|gflags|fmt"

# 应该看到类似输出：
# glog      0.7.1      hbabe93e_0    conda-forge
# gflags    2.2.2      he1b5a44_1004 conda-forge
# fmt       10.2.1     h00ab1b0_0    conda-forge
```

### 2. 运行诊断脚本

```bash
chmod +x check_cmake_configs.sh
./check_cmake_configs.sh
```

这会检查：
- CMake config 文件是否存在
- 库文件是否存在
- 头文件是否存在

### 3. 测试 CMake 查找

```bash
chmod +x test_cmake_find.sh
./test_cmake_find.sh
```

这会测试 CMake 是否能够找到并创建 targets。

### 4. 构建项目

```bash
# 使用系统库（推荐）
export USE_SYSTEM_LIBS=1
cmake -B build -S .
cmake --build build

# 或使用静态库
unset USE_SYSTEM_LIBS
cmake -B build -S .
cmake --build build
```

## 常见问题

### Q1: conda list 显示 glog 已安装，但 CMake 找不到

**原因**: conda-forge 的某些版本的 glog 不提供 CMake config 文件。

**解决**: 本项目的改进会自动创建 imported target，无需手动干预。

### Q2: 如何验证 target 是否创建成功？

运行 CMake 配置时，查看输出：

```
-- ✓ glog::glog target is available
-- ✓ gflags::gflags target is available
-- ✓ fmt::fmt target is available
```

或者：

```
-- Created glog::glog imported target from: /path/to/libglog.so
```

### Q3: 构建失败，提示找不到 glog/logging.h

**可能原因**:
1. glog 未安装：`conda install -c conda-forge glog`
2. CONDA_PREFIX 未设置：确保 conda 环境已激活
3. 头文件路径不正确：检查 `$CONDA_PREFIX/include/glog/logging.h` 是否存在

### Q4: 链接时出错，找不到 -lglog

**可能原因**:
1. 库文件不存在：检查 `$CONDA_PREFIX/lib/libglog.so` 或 `libglog.a`
2. 需要重新安装：`conda install --force-reinstall -c conda-forge glog`

## 技术细节

### 为什么使用 UNKNOWN IMPORTED？

```cmake
add_library(glog::glog UNKNOWN IMPORTED)
```

`UNKNOWN` 类型让 CMake 根据文件扩展名自动判断是静态库还是动态库。

### 为什么使用 NO_DEFAULT_PATH？

```cmake
find_library(GLOG_LIBRARY NAMES glog PATHS "$ENV{CONDA_PREFIX}/lib" NO_DEFAULT_PATH)
```

`NO_DEFAULT_PATH` 确保只在指定路径查找，避免意外使用系统库。

### 搜索路径优先级

CMake 会按以下顺序搜索：

1. `$CONDA_PREFIX/lib/cmake/<package>`
2. `$CONDA_PREFIX/lib64/cmake/<package>`
3. `$CONDA_PREFIX/share/cmake/<package>`
4. `$CONDA_PREFIX/lib/lib<package>.so`
5. 传统 `-l<package>` 链接

## 调试技巧

### 启用 CMake 查找调试

```bash
cmake -B build -S . -DCMAKE_FIND_DEBUG_MODE=ON
```

这会显示 CMake 查找包的详细过程。

### 手动指定包位置

如果自动查找失败，可以手动指定：

```bash
cmake -B build -S . \
  -Dglog_DIR=$CONDA_PREFIX/lib/cmake/glog \
  -Dgflags_DIR=$CONDA_PREFIX/lib/cmake/gflags \
  -Dfmt_DIR=$CONDA_PREFIX/lib/cmake/fmt
```

### 检查 imported target 属性

在 CMakeLists.txt 中添加：

```cmake
if(TARGET glog::glog)
    get_target_property(GLOG_LOC glog::glog IMPORTED_LOCATION)
    get_target_property(GLOG_INC glog::glog INTERFACE_INCLUDE_DIRECTORIES)
    message(STATUS "glog location: ${GLOG_LOC}")
    message(STATUS "glog includes: ${GLOG_INC}")
endif()
```

## 相关文件

- `CMakeLists.txt` - 主配置文件（包含三层回退机制）
- `check_cmake_configs.sh` - 检查 CMake config 文件
- `test_cmake_find.sh` - 测试依赖查找
- `CMAKE_TARGETS_GUIDE.md` - CMake targets 使用指南

