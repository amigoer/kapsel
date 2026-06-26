import XCTest
@testable import KapselKit

/// KapselKit 业务核心库的单元测试类
final class KapselKitTests: XCTestCase {
    
    /// 测试 Container 实体模型的初始化及属性字段映射
    func testContainerInitialization() {
        let container = Container(
            name: "test-nginx",
            image: "nginx:alpine",
            status: .running,
            ipAddress: "192.168.64.10",
            createdAt: nil
        )
        
        XCTAssertEqual(container.name, "test-nginx")
        XCTAssertEqual(container.image, "nginx:alpine")
        XCTAssertEqual(container.status, .running)
        XCTAssertEqual(container.ipAddress, "192.168.64.10")
        XCTAssertEqual(container.status.displayName, "运行中")
    }
    
    /// 测试 ContainerImage 实体模型的格式化方法
    func testContainerImageFormattedSize() {
        let image = ContainerImage(
            repository: "library/redis",
            tag: "7.2",
            digest: "sha256:12345",
            sizeBytes: 104857600 // 100 MB
        )
        
        XCTAssertEqual(image.fullName, "library/redis:7.2")
        // 验证字节转换格式，这里只检测是否包含 "MB" 标志
        XCTAssertTrue(image.formattedSize.contains("MB"))
    }
}
