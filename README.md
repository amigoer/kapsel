# Kapsel

A native, elegant macOS GUI client for Apple's open-source container engine [apple/container](https://github.com/apple/container).

**Kapsel** (German for Capsule) brings the power of Apple's high-performance Linux container virtualization framework to a native macOS interface. Built entirely in Swift and SwiftUI, it helps developers manage virtualized Linux environments, images, and OCI containers natively on Apple Silicon.

---

## Key Features

- **📊 Modern Dashboard:** Live virtualization telemetry tracking CPU, Memory, and Disk allocations for the VM layer.
- **📦 Container Lifecycle:** Fast graphical control (Start, Stop, Restart, Delete) over active container instances.
- **🖥️ Integrated Logs:** View real-time output streams from virtualized Linux environments directly in a custom terminal terminal-styled console.
- **💾 Image Management:** Pull images from standard OCI-compliant registries (Docker Hub, GitHub Container Registry) or build locally.
- **⚙️ Native Preferences:** Fine-tune CPU limits, memory constraints, storage partitions, and toggle between local engine and demo mock modes automatically.

---

## Architectural Layout

The project follows a clean, decoupled modular Swift architecture:

```
├── Package.swift           # Swift Package Manager configuration
├── Sources
│   ├── KapselKit           # Core library containing models and engine bridges
│   │   ├── Models          # Container & Image data structures
│   │   └── Services        # Process wrapper (CLIService), Container & Image Managers
│   └── KapselApp           # Native SwiftUI macOS application skeleton
│       └── Views           # Dashboard, Lists, Settings, and Detail views
└── README.md
```

### KapselKit
A standalone logic package that interfaces with the `container` executable via Swift's `Process` APIs. It parses structured JSON outputs and features an **automatic Demo/Mock fall-back** mode. If the underlying `container` engine isn't installed locally, the GUI degrades gracefully to mock data, allowing UI developers to work uninterrupted.

### KapselApp
The SwiftUI-based shell that binds to services provided by `KapselKit`. Optimized for macOS 14+, utilizing modern Navigation Split Views and declarative layouts.

---

## Getting Started

### Prerequisites

- **Processor:** Apple Silicon Mac (M1/M2/M3/M4). Intel Macs are not supported by the underlying virtualization framework.
- **OS:** macOS Sonoma (14.0) or later.
- **Engine:** Apple's official `container` CLI utility. Please refer to [apple/container](https://github.com/apple/container) to compile and install the CLI utility. By default, Kapsel looks for the executable in `/opt/homebrew/bin/container`.

### Building from Command Line

To test and compile the core library targets, execute:

```bash
swift build
```

To run unit tests:

```bash
swift test
```

### Developing in Xcode

1. Open Xcode.
2. Select **File > Open** and choose the `kapsel` root directory (Xcode will automatically resolve the Swift Package structure).
3. To run the graphical interface, you can drag the contents of `Sources/KapselApp` into a standard macOS SwiftUI App template or launch via Swift Playgrounds.

---

## License

This project is licensed under the Apache 2.0 License - see the LICENSE file for details.
