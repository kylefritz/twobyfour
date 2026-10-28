import Testing
import TwoByFourKit

/// What Send Logs says about an iPhone. Runs in the simulator.
@Suite struct IdentityTests {
    @Test func identityOnIPhone() {
        let id = Identity.current()
        #expect(id.platform == "iOS")
        #expect(id.osVersion.split(separator: ".").count == 3)
        #expect(id.model.hasPrefix("iPhone"))
    }
}
