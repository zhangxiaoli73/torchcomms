# build_ncclx.sh 和 build_rcclx.sh 中的 glog 版本限制

## 🔍 检查结果

### build_ncclx.sh

**是的，有限制 glog v0.4.0！**

#### 从源码编译时（USE_SYSTEM_LIBS 未设置）

<augment_code_snippet path="build_ncclx.sh" mode="EXCERPT">
```bash
# 第 152-153 行
build_fb_oss_library "https://github.com/google/glog.git" "v0.4.0" glog
build_fb_oss_library "https://github.com/google/glog.git" "v0.4.0" glog "-DBUILD_SHARED_LIBS=ON"
```
</augment_code_snippet>

#### 使用 conda 包时（USE_SYSTEM_LIBS=1）

<augment_code_snippet path="build_ncclx.sh" mode="EXCERPT">
```bash
# 第 176 行
glog==0.4.0
```
</augment_code_snippet>

### build_rcclx.sh

**是的，也有限制 glog v0.4.0！**

#### 从源码编译时（USE_SYSTEM_LIBS 未设置）

<augment_code_snippet path="build_rcclx.sh" mode="EXCERPT">
```bash
# 第 150-151 行
build_fb_oss_library "https://github.com/google/glog.git" "v0.4.0" glog
build_fb_oss_library "https://github.com/google/glog.git" "v0.4.0" glog "-DBUILD_SHARED_LIBS=ON"
```
</augment_code_snippet>

#### 使用 conda 包时（USE_SYSTEM_LIBS=1）

<augment_code_snippet path="build_rcclx.sh" mode="EXCERPT">
```bash
# 第 173 行
glog==0.4.0
```
</augment_code_snippet>

### build_rccl.sh

**没有 glog 依赖！**

`build_rccl.sh` 只构建 RCCL 库本身，不涉及 glog。

---

## 📊 完整对比表

| 构建脚本 | 从源码编译 glog 版本 | conda 包 glog 版本 | 是否限制版本 |
|---------|---------------------|-------------------|-------------|
| **build_ncclx.sh** | v0.4.0 (第 152-153 行) | v0.4.0 (第 176 行) | ✅ 是 |
| **build_rcclx.sh** | v0.4.0 (第 150-151 行) | v0.4.0 (第 173 行) | ✅ 是 |
| **build_rccl.sh** | N/A | N/A | ❌ 否（不使用 glog） |

---

## 🎯 关键发现

### 1. 两种构建模式都限制了 glog v0.4.0

#### 模式 A: 从源码编译（默认）

```bash
# 不设置 USE_SYSTEM_LIBS，或设置为空
./build_ncclx.sh
./build_rcclx.sh
```

**行为：**
- 从 GitHub 克隆 glog v0.4.0 源码
- 用 C++20 编译（第 21 行：`-DCMAKE_CXX_STANDARD=20`）
- 安装到 `$CONDA_PREFIX`

**为什么能工作：**
- ✅ 从源码编译时，CMake 会生成 `config.h`
- ✅ 用 C++20 编译 glog 本身
- ✅ `TorchCommLogging.hpp` 预先包含了 `<ctime>`

#### 模式 B: 使用 conda 包

```bash
# 设置 USE_SYSTEM_LIBS=1
USE_SYSTEM_LIBS=1 ./build_ncclx.sh
USE_SYSTEM_LIBS=1 ./build_rcclx.sh
```

**行为：**
- 通过 conda 安装 `glog==0.4.0`
- 使用预编译的二进制包（C++11）

**为什么能工作（对 NCCLX/RCCLX）：**
- ✅ `TorchCommLogging.hpp` 预先包含了 `<ctime>`
- ✅ 所有使用 glog 的文件都通过这个头文件

**为什么不能工作（对 XCCL）：**
- ❌ 某些 XCCL 文件可能没有预先包含 `<ctime>`
- ❌ 预编译包是 C++11，与 C++20 不完全兼容

### 2. 为什么脚本还在用 v0.4.0？

#### 可能的原因

1. **历史遗留**
   - 脚本创建于 2018-2019 年
   - 当时 v0.4.0 是最新版本
   - 一直没有更新

2. **依赖锁定**
   - 可能担心升级会破坏兼容性
   - 但实际上 glog v0.6.0+ 是向后兼容的

3. **没人测试**
   - 从源码编译模式能工作
   - 没人测试 conda 包模式 + XCCL

---

## ✅ 建议的修改

### 方案 1: 升级到 glog v0.7.0（推荐）⭐

#### 修改 build_ncclx.sh

```bash
# 第 152-153 行，改为：
build_fb_oss_library "https://github.com/google/glog.git" "v0.7.0" glog
build_fb_oss_library "https://github.com/google/glog.git" "v0.7.0" glog "-DBUILD_SHARED_LIBS=ON"

# 第 176 行，改为：
glog==0.7.0
```

#### 修改 build_rcclx.sh

```bash
# 第 150-151 行，改为：
build_fb_oss_library "https://github.com/google/glog.git" "v0.7.0" glog
build_fb_oss_library "https://github.com/google/glog.git" "v0.7.0" glog "-DBUILD_SHARED_LIBS=ON"

# 第 173 行，改为：
glog==0.7.0
```

### 方案 2: 只修改 conda 包版本（临时方案）

如果担心从源码编译 v0.7.0 会有问题，可以只修改 conda 包版本：

```bash
# build_ncclx.sh 第 176 行
glog==0.7.0  # 改为 v0.7.0

# build_rcclx.sh 第 173 行
glog==0.7.0  # 改为 v0.7.0

# 保持从源码编译的版本不变（v0.4.0）
```

**但不推荐这样做**，因为会导致两种模式使用不同版本。

---

## 🧪 测试建议

### 测试 1: NCCLX 从源码编译（升级到 v0.7.0）

```bash
# 修改 build_ncclx.sh 中的 glog 版本为 v0.7.0
./build_ncclx.sh

# 测试
export USE_NCCLX=ON
export USE_NCCL=OFF
export USE_XCCL=OFF
pip install --no-build-isolation -v .
```

### 测试 2: NCCLX conda 包模式（升级到 v0.7.0）

```bash
# 修改 build_ncclx.sh 中的 conda glog 版本为 v0.7.0
USE_SYSTEM_LIBS=1 ./build_ncclx.sh

# 测试
export USE_NCCLX=ON
export USE_NCCL=OFF
export USE_XCCL=OFF
export USE_SYSTEM_LIBS=1
pip install --no-build-isolation -v .
```

### 测试 3: RCCLX（升级到 v0.7.0）

```bash
# 修改 build_rcclx.sh 中的 glog 版本为 v0.7.0
./build_rcclx.sh

# 测试
export USE_RCCLX=ON
export USE_RCCL=OFF
pip install --no-build-isolation -v .
```

---

## 📝 总结

### 回答你的问题

**问：build_ncclx.sh 和 build_rcclx.sh 里面有没有限制 glog 的版本？**

**答：是的，都限制了 glog v0.4.0！**

- ✅ `build_ncclx.sh` 第 152-153 行（从源码）和第 176 行（conda）
- ✅ `build_rcclx.sh` 第 150-151 行（从源码）和第 173 行（conda）
- ❌ `build_rccl.sh` 不使用 glog

### 为什么 NCCLX/RCCLX 能用 v0.4.0？

1. **从源码编译模式**：用 C++20 编译 glog，能工作
2. **conda 包模式**：`TorchCommLogging.hpp` 预先包含了 `<ctime>`

### 为什么 XCCL 不能用 v0.4.0？

1. **使用 conda 包**：预编译的 C++11 版本
2. **没有预先包含 `<ctime>`**：某些文件直接包含 glog

### 最佳解决方案

**升级所有构建脚本中的 glog 到 v0.7.0！**

这样可以：
- ✅ 解决 XCCL 的编译问题
- ✅ 获得更好的性能和 bug 修复
- ✅ 统一所有 backend 的依赖版本
- ✅ 避免未来的兼容性问题

