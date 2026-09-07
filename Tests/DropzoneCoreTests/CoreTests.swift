import XCTest
import CoreGraphics
@testable import DropzoneCore

final class MotionTests: XCTestCase {
    func testInertiaRampsUpAndBrakesGradually() {
        var follower = InertialFollower()
        var point = CGPoint.zero
        let target = CGPoint(x: 1000, y: 0)
        point = follower.advance(from: point, to: target, deltaTime: 1 / 60)
        let initialSpeed = follower.speed
        XCTAssertGreaterThan(initialSpeed, 0)
        XCTAssertLessThan(point.x, 50, "The first frame eases in rather than jumping to the target")
        for _ in 0..<20 { point = follower.advance(from: point, to: target, deltaTime: 1 / 60) }
        let movingSpeed = follower.speed
        point = follower.advance(from: point, to: target, deltaTime: 1 / 60, mobility: 0)
        XCTAssertGreaterThan(follower.speed, 0)
        XCTAssertLessThan(follower.speed, movingSpeed)
        for _ in 0..<180 { point = follower.advance(from: point, to: target, deltaTime: 1 / 60, mobility: 0) }
        XCTAssertEqual(follower.speed, 0)
    }
    func testSideSwapPreservesVelocityContinuity() {
        var follower = InertialFollower()
        var point = CGPoint.zero
        let target = CGPoint(x: 1200, y: 0)
        for _ in 0..<6 { point = follower.advance(from: point, to: target, deltaTime: 1 / 60) }
        let before = follower.velocity.x
        let next = follower.advance(from: point, to: CGPoint(x: -1200, y: 0), deltaTime: 0.001)
        XCTAssertGreaterThan(follower.velocity.x, 0, "A target swap should brake the current movement before reversing")
        XCTAssertLessThan(abs(follower.velocity.x - before), before * 0.2)
        XCTAssertLessThan(hypot(next.x - point.x, next.y - point.y), 10)
    }
    func testFollowRegainsResponsivePaceWithoutOvershoot() {
        var follower = InertialFollower()
        var point = CGPoint.zero
        let target = CGPoint(x: 1000, y: 0)
        for _ in 0..<18 {
            point = follower.advance(from: point, to: target, deltaTime: 1 / 60)
            XCTAssertLessThanOrEqual(point.x, target.x)
        }
        XCTAssertGreaterThan(point.x, 950, "A stationary target should be almost reached in 300 ms, as before the slowdown")
    }
    func testApproachProgressivelyReducesMobility() {
        XCTAssertEqual(InertialFollower.mobility(clearance: 20), 0)
        XCTAssertEqual(InertialFollower.mobility(clearance: 150), 1)
        XCTAssertGreaterThan(InertialFollower.mobility(clearance: 120), InertialFollower.mobility(clearance: 80))
        XCTAssertEqual(InertialFollower.clearance(pointer: CGPoint(x: 150, y: 50), frame: CGRect(x: 0, y: 0, width: 100, height: 100)), 50)
    }
    func testInertiaEventuallySettles() {
        var follower = InertialFollower()
        var point = CGPoint.zero
        let target = CGPoint(x: 400, y: 100)
        for _ in 0..<900 { point = follower.advance(from: point, to: target, deltaTime: 1 / 60) }
        XCTAssertEqual(point.x, target.x, accuracy: 0.5)
        XCTAssertEqual(point.y, target.y, accuracy: 0.5)
        XCTAssertEqual(follower.speed, 0)
    }
    func testShakeDetectsRepeatedIntentionalReversals() {
        var detector = ShakeDetector()
        let xs: [CGFloat] = [0, 45, 0, 48, 0, 45]
        let hits = xs.enumerated().map { detector.update(point: CGPoint(x: $0.element, y: 0), time: Double($0.offset) * 0.08) }
        XCTAssertTrue(hits.contains(true))
    }
    func testOrdinaryDragAndJitterDoNotShake() {
        var straight = ShakeDetector(); var jitter = ShakeDetector()
        for i in 0..<100 {
            XCTAssertFalse(straight.update(point: CGPoint(x: i * 10, y: 20), time: Double(i) * 0.02))
            XCTAssertFalse(jitter.update(point: CGPoint(x: i % 2 == 0 ? 4 : 0, y: 0), time: Double(i) * 0.02))
        }
    }
    func testShakeResetPreventsCombiningTwoDrags() {
        var detector = ShakeDetector()
        for (i, x) in [0, 50, 0].enumerated() { _ = detector.update(point: CGPoint(x: x, y: 0), time: Double(i) * 0.06) }
        detector.reset()
        for (i, x) in [50, 0, 50].enumerated() { XCTAssertFalse(detector.update(point: CGPoint(x: x, y: 0), time: 0.2 + Double(i) * 0.06)) }
    }
    func testFollowSwitchesSideOnlyAfterSustainedDirection() {
        var motion = FollowMotion()
        motion.observe(CGPoint(x: 500, y: 500), time: 0)
        motion.observe(CGPoint(x: 490, y: 500), time: 0.05)
        XCTAssertEqual(motion.side, -1)
        motion.observe(CGPoint(x: 470, y: 500), time: 0.21)
        XCTAssertEqual(motion.side, 1)
    }
    func testFollowFreezesBeforePointerReachesPanel() {
        var motion = FollowMotion()
        let frame = CGRect(x: 200, y: 200, width: 252, height: 254)
        XCTAssertTrue(motion.isPaused(pointer: CGPoint(x: 180, y: 300), frame: frame, time: 1, interacting: false))
        XCTAssertTrue(motion.isPaused(pointer: CGPoint(x: 120, y: 300), frame: frame, time: 2, interacting: false))
        XCTAssertTrue(motion.isPaused(pointer: CGPoint(x: 50, y: 300), frame: frame, time: 2.1, interacting: false))
        XCTAssertFalse(motion.isPaused(pointer: CGPoint(x: 50, y: 300), frame: frame, time: 2.5, interacting: false))
    }
    func testMenuInteractionPausesFollowAtAnyDistance() {
        var motion = FollowMotion()
        XCTAssertTrue(motion.isPaused(pointer: .zero, frame: CGRect(x: 500, y: 500, width: 252, height: 254), time: 1, interacting: true))
    }
    func testFollowClampedToNegativeOriginDisplay() {
        let motion = FollowMotion()
        let screen = CGRect(x: -1440, y: -200, width: 1440, height: 900)
        let size = CGSize(width: 252, height: 254)
        for p in [CGPoint(x: -1435, y: -195), CGPoint(x: -5, y: 695), CGPoint(x: -720, y: 250)] {
            let target = motion.target(pointer: p, size: size, screen: screen)
            XCTAssertTrue(screen.contains(CGRect(origin: target, size: size)))
        }
    }
    func testFollowStepDoesNotOvershootAndConverges() {
        var position = CGPoint.zero
        let destination = CGPoint(x: 400, y: 250)
        for _ in 0..<200 { position = FollowMotion.step(from: position, to: destination, deltaTime: 1 / 60) }
        XCTAssertEqual(position.x, destination.x, accuracy: 0.01)
        XCTAssertEqual(position.y, destination.y, accuracy: 0.01)
        XCTAssertEqual(FollowMotion.step(from: .zero, to: destination, deltaTime: 0), .zero)
        XCTAssertLessThan(FollowMotion.step(from: .zero, to: destination, deltaTime: 10).x, destination.x)
    }
}

final class FileTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    private func file(_ name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("original contents".utf8).write(to: url)
        return url
    }
    func testSameFileDeduplicatesButSameNameDoesNot() throws {
        let one = try FileReference(url: file("a/новый.txt"))
        let two = try FileReference(url: file("b/новый.txt"))
        var shelf = ShelfInventory(); shelf.append([one, one, two])
        XCTAssertEqual(shelf.items.count, 2)
        XCTAssertNotEqual(one.id, two.id)
    }
    func testRemovingAndClearingNeverChangesOriginals() throws {
        let url = try file("keep.txt")
        let before = try Data(contentsOf: url)
        let entry = try FileReference(url: url)
        var shelf = ShelfInventory(); shelf.append([entry]); shelf.remove(ids: [entry.id])
        XCTAssertEqual(try Data(contentsOf: url), before)
        shelf.append([entry]); shelf.clear()
        XCTAssertEqual(try Data(contentsOf: url), before)
        XCTAssertTrue(shelf.items.isEmpty)
    }
    func testMissingFileIsMarkedUnavailable() throws {
        let url = try file("gone.txt"); let entry = try FileReference(url: url)
        try FileManager.default.removeItem(at: url)
        XCTAssertFalse(entry.refreshed().available)
    }
    func testBookmarkFollowsExternalRename() throws {
        let url = try file("before.txt"); let entry = try FileReference(url: url)
        let renamed = directory.appendingPathComponent("after.txt")
        try FileManager.default.moveItem(at: url, to: renamed)
        let updated = entry.refreshed()
        XCTAssertEqual(updated.id, entry.id)
        XCTAssertTrue(updated.available)
        XCTAssertEqual(updated.name, "after.txt")
    }
    func testDirectoryReferenceDoesNotEnumerateOrCopyContents() throws {
        _ = try file("folder/subdir/item.txt")
        let entry = try FileReference(url: directory.appendingPathComponent("folder"))
        XCTAssertTrue(entry.isDirectory)
        XCTAssertTrue(entry.available)
    }
}

final class ClosePolicyTests: XCTestCase {
    func testOnlyCountsStrictlyAboveThresholdRequireConfirmation() {
        for count in [0, 1, 5] { XCTAssertFalse(ClosePolicy.requiresConfirmation(count: count, enabled: true, threshold: 5)) }
        XCTAssertTrue(ClosePolicy.requiresConfirmation(count: 6, enabled: true, threshold: 5))
    }
    func testThresholdAndToggleAreRespected() {
        XCTAssertFalse(ClosePolicy.requiresConfirmation(count: 30, enabled: true, threshold: 30))
        XCTAssertTrue(ClosePolicy.requiresConfirmation(count: 31, enabled: true, threshold: 30))
        XCTAssertFalse(ClosePolicy.requiresConfirmation(count: 1000, enabled: false, threshold: 5))
    }
}
