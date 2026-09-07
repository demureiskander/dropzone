import Foundation
import CoreGraphics

public struct ShakeDetector {
    private var samples: [(CGPoint, TimeInterval)] = []
    private var lastTrigger: TimeInterval = -.infinity
    public init() {}
    public mutating func reset() { samples.removeAll() }

    public mutating func update(point: CGPoint, time: TimeInterval, sensitivity: Double = 1) -> Bool {
        samples.append((point, time))
        samples.removeAll { time - $0.1 > 0.55 }
        guard time - lastTrigger > 1, samples.count >= 5 else { return false }
        // Reject jitter and long, mostly straight drags. Count significant direction changes.
        let threshold = 14 / max(0.5, sensitivity)
        var anchor = samples[0].0.x
        var direction = 0
        var reversals = 0
        var distance: CGFloat = 0
        for sample in samples.dropFirst() {
            let dx = sample.0.x - anchor
            guard abs(dx) >= threshold else { continue }
            let next = dx > 0 ? 1 : -1
            if direction != 0 && next != direction { reversals += 1 }
            direction = next
            distance += abs(dx)
            anchor = sample.0.x
        }
        guard reversals >= 3, distance >= 100 / sensitivity else { return false }
        lastTrigger = time
        reset()
        return true
    }
}

/// Continuous velocity makes a new target (including a side swap) a turn rather than a jump.
public struct InertialFollower {
    public private(set) var velocity = CGPoint.zero
    public var speed: CGFloat { hypot(velocity.x, velocity.y) }
    public init() {}
    public mutating func reset() { velocity = .zero }

    public static func clearance(pointer: CGPoint, frame: CGRect) -> CGFloat {
        let dx = max(frame.minX - pointer.x, 0, pointer.x - frame.maxX)
        let dy = max(frame.minY - pointer.y, 0, pointer.y - frame.maxY)
        return hypot(dx, dy)
    }

    public static func mobility(clearance: CGFloat) -> CGFloat {
        let t = min(max((clearance - 40) / 110, 0), 1)
        return t * t * (3 - 2 * t)
    }

    public mutating func advance(from: CGPoint, to: CGPoint, deltaTime: Double, mobility: CGFloat = 1, reduceMotion: Bool = false) -> CGPoint {
        let dt = min(max(deltaTime, 0), 0.035)
        guard dt > 0 else { return from }
        let mobility = min(max(mobility, 0), 1)
        let target = CGPoint(x: from.x + (to.x - from.x) * mobility, y: from.y + (to.y - from.y) * mobility)
        // Critically damped spring: original responsive pace without a speed cap.
        // Exact integration preserves velocity through turns and does not oscillate.
        let omega: CGFloat = reduceMotion ? 26 : 18
        let decay = exp(-omega * dt)
        let error = CGPoint(x: from.x - target.x, y: from.y - target.y)
        let impulse = CGPoint(x: (velocity.x + omega * error.x) * dt, y: (velocity.y + omega * error.y) * dt)
        let next = CGPoint(x: target.x + (error.x + impulse.x) * decay, y: target.y + (error.y + impulse.y) * decay)
        velocity = CGPoint(x: (velocity.x - omega * impulse.x) * decay, y: (velocity.y - omega * impulse.y) * decay)
        if speed < 0.6 && (hypot(next.x - to.x, next.y - to.y) < 0.5 || mobility == 0) { velocity = .zero }
        return next
    }
}

public struct FollowMotion {
    public private(set) var side: CGFloat = -1
    private var lastPoint: CGPoint?
    private var candidateSide: CGFloat = -1
    private var candidateSince: TimeInterval = 0
    private var paused = false
    private var resumeAt: TimeInterval = 0
    public init() {}

    public mutating func observe(_ point: CGPoint, time: TimeInterval) {
        defer { lastPoint = point }
        guard let old = lastPoint else { return }
        let dx = point.x - old.x
        guard abs(dx) > 2 else { return }
        let desired: CGFloat = dx > 0 ? -1 : 1
        if desired != candidateSide { candidateSide = desired; candidateSince = time }
        if time - candidateSince >= 0.14 { side = desired }
    }

    public mutating func isPaused(pointer: CGPoint, frame: CGRect, time: TimeInterval, interacting: Bool) -> Bool {
        if interacting || frame.insetBy(dx: -48, dy: -48).contains(pointer) {
            paused = true
            resumeAt = time + 0.3
            return true
        }
        if paused && frame.insetBy(dx: -88, dy: -88).contains(pointer) {
            resumeAt = time + 0.3
            return true
        }
        if time < resumeAt { return true }
        paused = false
        return false
    }

    public func target(pointer: CGPoint, size: CGSize, screen: CGRect) -> CGPoint {
        let gap: CGFloat = 64
        var x = side < 0 ? pointer.x - size.width - gap : pointer.x + gap
        if x < screen.minX || x + size.width > screen.maxX {
            let other = side < 0 ? pointer.x + gap : pointer.x - size.width - gap
            if other >= screen.minX && other + size.width <= screen.maxX { x = other }
        }
        // Keep a vertical clearance so side changes travel around the pointer.
        var y = pointer.y - size.height - gap
        if y < screen.minY { y = pointer.y + gap }
        return Self.clamp(CGPoint(x: x, y: y), size: size, screen: screen)
    }

    public static func clamp(_ point: CGPoint, size: CGSize, screen: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, screen.minX + 8), max(screen.minX + 8, screen.maxX - size.width - 8)),
                y: min(max(point.y, screen.minY + 8), max(screen.minY + 8, screen.maxY - size.height - 8)))
    }

    public static func step(from: CGPoint, to: CGPoint, deltaTime: Double, reduceMotion: Bool = false) -> CGPoint {
        let alpha = 1 - exp(-min(max(deltaTime, 0), 0.05) * (reduceMotion ? 22 : 11))
        return CGPoint(x: from.x + (to.x - from.x) * alpha, y: from.y + (to.y - from.y) * alpha)
    }
}
