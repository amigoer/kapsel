# Kapsel

针对苹果开源容器引擎 [apple/container](https://github.com/apple/container) 的原生、优雅的 macOS GUI 客户端。

**Kapsel**（德语中意为“胶囊”）旨在为苹果的高性能 Linux 容器虚拟化框架提供原生的 macOS 图形交互界面。项目完全基于 Swift 和 SwiftUI 开发，协助开发者在 Apple Silicon 芯片上直观、顺畅地管理轻量级 Linux 虚拟机沙盒、OCI 容器和镜像。

---

## 核心特性

- **📊 现代仪表盘:** 实时监控底层虚拟机沙盒的虚拟 CPU 核心、虚拟内存和虚拟磁盘分配与利用率。
- **📦 容器生命周期管理:** 提供对容器实例的图形化一键控制（启动、停止、重启、删除）。
- **🖥️ 控制台日志:** 在终端风格的控制台视图中，异步拉取并查看正在运行的 Linux 容器实时日志。
- **💾 镜像管理:** 检索并管理本地下载的 OCI 镜像；支持从常用的 OCI 注册表（如 Docker Hub、GitHub Container Registry）拉取新镜像，或直接通过本地 Dockerfile 编译构建。
- **⚙️ 原生设置面板:** 灵活配置虚拟机 CPU 核数限制、内存和磁盘规格上限，支持自动检测 CLI 环境并在“演示模式”与“物理运行模式”之间自动切换。

---

## 架构划分

项目基于解耦的模块化 Swift 工程结构设计：

```
├── Package.swift           # Swift Package Manager 包配置文件
├── Sources
│   ├── KapselKit           # 核心业务逻辑库（包含数据模型、解析服务及底层通信桥梁）
│   │   ├── Models          # 容器 (Container) 与镜像 (Image) 的实体声明
│   │   └── Services        # CLI 进程执行封装 (CLIService) 及各项核心业务接口
│   └── KapselApp           # 原生 SwiftUI macOS 应用程序外壳
│       └── Views           # 包含仪表盘、管理列表、系统设置等视图组件
└── README.zh-CN.md
```

### KapselKit
这是一个独立的业务逻辑 Package，使用 Swift 的 `Process` API 与底层的 `container` 二进制可执行文件进行进程间通信。它原生支持 JSON 格式解析，并具备**自动降级演示（Mock）机制**。如果用户的 macOS 系统尚未编译或安装 `apple/container` 引擎，GUI 会自动降级为展示演示数据，确保界面开发或原型评审不被打断。

### KapselApp
利用 SwiftUI 搭建的交互壳体。深度适配 macOS 14+ 新增的 `NavigationSplitView` 布局，并完全使用声明式状态管理。

---

## 快速入门

### 软硬件环境要求

- **硬件处理器:** Apple Silicon 芯片系列（M1/M2/M3/M4）。底层虚拟化框架在英特尔 Intel Mac 上无法使用。
- **操作系统:** macOS Sonoma (14.0) 或更高版本。
- **底层引擎:** 苹果官方 `container` 命令行工具。具体编译与安装指南请参见 [apple/container](https://github.com/apple/container) 仓库。Kapsel 默认在 `/opt/homebrew/bin/container` 寻找该可执行程序。

### 命令行编译

若想编译测试 KapselKit 核心逻辑库，在终端执行：

```bash
swift build
```

运行单元测试：

```bash
swift test
```

### 使用 Xcode 进行开发

1. 启动 Xcode。
2. 选择 **File > Open**，然后定位并选择 `kapsel` 的根目录（Xcode 将自动解析 SPM 包依赖并将其转化为工作区）。
3. 如果需要运行 GUI 界面，可以将 `Sources/KapselApp` 的代码直接拖入新建的标准 macOS SwiftUI App 模板中编译，或通过 Swift Playgrounds 运行。

---

## 开源许可证

本项目基于 Apache 2.0 许可证进行开源 - 详见 LICENSE 文件。
