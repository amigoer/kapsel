import XCTest
@testable import KapselKit

/// KapselKit 业务核心库的单元测试类
final class KapselKitTests: XCTestCase {
    
    /// 测试 Container 实体模型的初始化及属性字段映射
    func testContainerInitialization() {
        let container = Container(
            containerID: "abc123",
            name: "test-nginx",
            image: "nginx:alpine",
            status: .running,
            address: "192.168.64.10",
            createdAt: nil
        )

        XCTAssertEqual(container.name, "test-nginx")
        XCTAssertEqual(container.image, "nginx:alpine")
        XCTAssertEqual(container.status, .running)
        XCTAssertEqual(container.address, "192.168.64.10")
        XCTAssertEqual(container.status.displayName, "Running")
    }
    
    /// 测试 ContainerImage 实体模型的格式化方法
    func testContainerImageFormattedSize() {
        let image = ContainerImage(
            repository: "library/redis",
            tag: "7.2",
            digest: "sha256:12345",
            size: "100 MB"
        )

        XCTAssertEqual(image.fullName, "library/redis:7.2")
        XCTAssertEqual(image.size, "100 MB")
    }

    /// 测试 SystemStatus JSON 解析与运行状态映射
    func testSystemStatusJSONDecoding() throws {
        let rawJSON = """
        {
          "apiServerAppName": "container-apiserver",
          "apiServerBuild": "release",
          "apiServerCommit": "ee848e3ebfd7c73b04dd419683be54fb450b8779",
          "apiServerVersion": "container-apiserver version 1.0.0 (build: release, commit: ee848e3)",
          "appRoot": "/Users/amigoer/Library/Application Support/com.apple.container/",
          "installRoot": "/usr/local/",
          "status": "running"
        }
        """

        let response = try SystemStatusResponse.decode(from: rawJSON)
        let status = SystemStatus(response: response)

        XCTAssertEqual(response.status, "running")
        XCTAssertTrue(status.isRunning)
        XCTAssertEqual(response.apiServerAppName, "container-apiserver")
    }

    /// 测试 engine 停止时的 JSON 解析
    func testSystemStatusNotRunningJSONDecoding() throws {
        let rawJSON = """
        {
          "status": "not running",
          "appRoot": "",
          "installRoot": "",
          "logRoot": null,
          "apiServerVersion": "",
          "apiServerCommit": "",
          "apiServerBuild": "",
          "apiServerAppName": ""
        }
        """

        let response = try SystemStatusResponse.decode(from: rawJSON)
        XCTAssertFalse(response.isRunning)
    }
}
