# Folly依赖问题修复指南

## 问题

构建时遇到错误：
```
Package libfolly was not found in the pkg-config search path.
Perhaps you should add the directory containing `libfolly.pc'
to the PKG_CONFIG_PATH environment variable
No package 'libfolly' found
CMake Error at comms/torchcomms/transport/CMakeLists.txt:59 (message):
  pkg-config for libfolly failed
```

## 根本原因

1. **缺少folly库**: 系统中没有安装Facebook的folly库
2. **pkg-config路径问题**: folly的`.pc`文件不在pkg-config的搜索路径中
3. **LIB_SUFFIX未定义**: CMakeLists.txt中`CONDA_LIB`路径构造错误

## 解决方案

### 方案1: 使用Conda安装Folly（推荐）

```bash
# 安装folly和相关依赖
conda install -c conda-forge folly glog gflags fmt boost double-conversion libevent

# 验证安装
pkg-config --libs libfolly
ls $CONDA_PREFIX/lib/pkgconfig/libfolly.pc

# 重新构建
rm -rf build/
pip install --no-build-isolation -v -e .
```

### 方案2: 使用系统库模式

```bash
# 设置环境变量使用系统库
export USE_SYSTEM_LIBS=1

# 安装系统folly（Ubuntu/Debian）
sudo apt-get install libfolly-dev libglog-dev libgflags-dev libfmt-dev

# 重新构建
rm -rf build/
pip install --no-build-isolation -v -e .
```

### 方案3: 从源码编译Folly

```bash
# 安装依赖
sudo apt-get install \
    g++ \
    cmake \
    libboost-all-dev \
    libevent-dev \
    libdouble-conversion-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    libiberty-dev \
    liblz4-dev \
    liblzma-dev \
    libsnappy-dev \
    make \
    zlib1g-dev \
    binutils-dev \
    libjemalloc-dev \
    libssl-dev \
    pkg-config \
    libsodium-dev \
    libunwind-dev \
    libdwarf-dev \
    libelf-dev \
    libfmt-dev

# 克隆并编译folly
git clone https://github.com/facebook/folly.git
cd folly
mkdir _build && cd _build
cmake -DCMAKE_INSTALL_PREFIX=$CONDA_PREFIX ..
make -j$(nproc)
make install

# 验证
pkg-config --libs libfolly
```

## 已应用的代码修复

### 1. 修复LIB_SUFFIX未定义问题

**文件**: `CMakeLists.txt`

```cmake
# Set LIB_SUFFIX (default to "lib", can be overridden by environment)
if(DEFINED ENV{LIB_SUFFIX})
  set(LIB_SUFFIX $ENV{LIB_SUFFIX})
else()
  set(LIB_SUFFIX "lib")
endif()

set(CONDA_LIB "${CONDA_PREFIX}/${LIB_SUFFIX}")
```

### 2. 添加Folly查找回退机制

**文件**: `comms/torchcomms/transport/CMakeLists.txt`

```cmake
# Get folly LDFLAGS using pkg-config
set(ENV{PKG_CONFIG_PATH} "${CONDA_LIB}/pkgconfig")
execute_process(
    COMMAND pkg-config --libs --static libfolly
    OUTPUT_VARIABLE FOLLY_LDFLAGS_RAW
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE PKG_RESULT
)
if(NOT PKG_RESULT EQUAL 0)
    message(WARNING "pkg-config for libfolly failed. Trying fallback...")
    
    # Fallback: manually construct folly link flags
    if(USE_SYSTEM_LIBS)
        set(FOLLY_LDFLAGS "-lfolly")
    else()
        find_library(FOLLY_LIB NAMES libfolly.a folly PATHS ${CONDA_LIB} NO_DEFAULT_PATH)
        if(FOLLY_LIB)
            set(FOLLY_LDFLAGS "${FOLLY_LIB}")
        else()
            message(FATAL_ERROR "Cannot find folly library")
        endif()
    endif()
endif()
```

## 验证步骤

### 1. 检查Conda环境

```bash
echo $CONDA_PREFIX
# 应该输出类似: /home/user/miniforge3/envs/your-env

ls $CONDA_PREFIX/lib/libfolly.*
# 应该看到 libfolly.a 或 libfolly.so
```

### 2. 检查pkg-config

```bash
pkg-config --modversion libfolly
# 应该输出folly版本号

pkg-config --libs libfolly
# 应该输出链接标志
```

### 3. 检查CMake变量

在构建输出中查找：
```
-- CONDA_PREFIX: /home/user/miniforge3/envs/your-env
-- CONDA_LIB: /home/user/miniforge3/envs/your-env/lib
-- PKG_CONFIG_PATH: /home/user/miniforge3/envs/your-env/lib/pkgconfig
```

## 常见问题

### Q: conda install folly失败

**A**: 尝试指定conda-forge频道：
```bash
conda install -c conda-forge folly
```

### Q: 系统中有多个folly版本

**A**: 确保使用正确的pkg-config路径：
```bash
export PKG_CONFIG_PATH=$CONDA_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
pkg-config --modversion libfolly
```

### Q: 编译folly时出错

**A**: 确保所有依赖都已安装，特别是：
- boost >= 1.51.0
- double-conversion
- glog
- gflags
- fmt

## 推荐配置

对于Intel GPU构建，推荐使用conda环境：

```bash
# 创建新环境
conda create -n intel-gpu-torch python=3.10

# 激活环境
conda activate intel-gpu-torch

# 安装PyTorch XPU
# (按照Intel的官方指南)

# 安装folly和依赖
conda install -c conda-forge \
    folly \
    glog \
    gflags \
    fmt \
    boost \
    double-conversion \
    libevent \
    level-zero \
    level-zero-dev

# 安装IB库
sudo apt-get install libibverbs-dev

# 构建torchcomms
export USE_INTEL_GPU=1
export USE_XCCL=ON
export USE_TRANSPORT=ON
export USE_NCCL=OFF
export USE_NCCLX=OFF

pip install --no-build-isolation -v -e .
```

## 相关文档

- `QUICK_START_INTEL_GPU.md` - 快速开始指南
- `INTEL_GPU_BUILD_FIX.md` - 其他构建问题修复
- `BUILD_STATUS.md` - 构建状态总结

