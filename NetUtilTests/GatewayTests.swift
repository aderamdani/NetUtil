import XCTest
@testable import NetUtil

@MainActor
final class GatewayTests: XCTestCase {
    func testGatewayParsing() {
        // Mock output
        let output = """
        Routing tables

        Internet:
        Destination        Gateway            Flags               Netif Expire
        default            192.168.110.1      UGScg                 en0       
        127                127.0.0.1          UCS                   lo0       
        """
        
        let lines = output.components(separatedBy: .newlines)
        var foundGateway: String?
        for line in lines {
            let parts = line.split(separator: " ").map { String($0) }
            if parts.count >= 4 && parts[0] == "default" && parts[3] == "en0" {
                foundGateway = parts[1]
            }
        }
        
        XCTAssertEqual(foundGateway, "192.168.110.1")
    }
}
