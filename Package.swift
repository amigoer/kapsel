// swift-tools-version: 6.0
// 用 Swift 6.0 构建 KapselKit 核心业务库

import PackageDescription

let package = Package(
    name: "Kapsel",
    platforms: [
        .macOS(.v14) // apple/container 需要运行在支持虚拟化的现代 macOS 上，这里要求 v14+
    ],
    products: [
        // 核心功能库，包含数据模型、服务层与 CLI 包装器
        .library(name: "KapselKit", targets: ["KapselKit"]),
    ],
    dependencies: [
        // 在此处添加三方库依赖（如需要）
    ],
    targets: [
        // 核心业务 Target
        .target(
            name: "KapselKit",
            dependencies: [],
            path: "Sources/KapselKit"
        ),
        // 将 KapselApp 声明为可执行 Target，以便在 Xcode 中可以直接运行拉起 GUI 界面
        .executableTarget(
            name: "KapselApp",
            dependencies: ["KapselKit"],
            path: "Sources/KapselApp"
        ),
        // 核心业务单元测试 Target
        .testTarget(
            name: "KapselKitTests",
            dependencies: ["KapselKit"],
            path: "Tests/KapselKitTests"
        )
    ]
)
