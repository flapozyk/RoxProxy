import XCTest
@testable import rox_proxy_native

class ProxyTests: XCTestCase {

    func testStartProxy() {
        let expectation = XCTestExpectation(description: "Start proxy successfully")
        
        // Mock or use a test-friendly implementation
        let proxyServer = ProxyServer(port: 8888, systemProxy: false)
        proxyServer.start { success in
            XCTAssertTrue(success, "Proxy should start successfully")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }

    func testStopProxy() {
        let expectation = XCTestExpectation(description: "Stop proxy successfully")
        
        let proxyServer = ProxyServer(port: 8888, systemProxy: false)
        proxyServer.stop { success in
            XCTAssertTrue(success, "Proxy should stop successfully")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }

    func testCertificateGeneration() {
        let expectation = XCTestExpectation(description: "Generate certificate successfully")
        
        let certificateAuthority = CertificateAuthority()
        certificateAuthority.initialize { success in
            XCTAssertTrue(success, "Certificate should be generated successfully")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
