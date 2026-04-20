import XCTest
@testable import ThreemaFramework
@testable import ThreemaProtocols

final class FSVersionObjectiveCSwiftCompatibilityCheck: XCTestCase {
    let allObjectiveCCases: [ObjcCspE2eFs_Version] = [
        ObjcCspE2eFs_Version.V10,
        ObjcCspE2eFs_Version.V11,
        ObjcCspE2eFs_Version.V12,
        ObjcCspE2eFs_Version.unspecified,
    ]
    
    func testAllCases() throws {
        for versionCase in CspE2eFs_Version.allCases {
            let objectiveCVersion = try XCTUnwrap(ObjcCspE2eFs_Version(rawValue: UInt(versionCase.rawValue)))
            XCTAssertTrue(allObjectiveCCases.contains(objectiveCVersion))
        }
    }
    
    func testOneCaseMissing() throws {
        let allObjectiveCCasesExceptUnspecified: [ObjcCspE2eFs_Version] = [
            ObjcCspE2eFs_Version.V10,
            ObjcCspE2eFs_Version.V11,
            ObjcCspE2eFs_Version.V12,
        ]
        
        for versionCase in CspE2eFs_Version.allCases {
            let objectiveCVersion = try XCTUnwrap(ObjcCspE2eFs_Version(rawValue: UInt(versionCase.rawValue)))
            if versionCase == .unspecified {
                XCTAssertFalse(allObjectiveCCasesExceptUnspecified.contains(objectiveCVersion))
            }
            else {
                XCTAssertTrue(allObjectiveCCasesExceptUnspecified.contains(objectiveCVersion))
            }
        }
    }
}
