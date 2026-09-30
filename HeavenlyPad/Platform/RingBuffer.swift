import Foundation
import Atomics

/// A lock-free Single-Producer Single-Consumer (SPSC) ring buffer.
public final class RingBuffer<T> {
    private let capacity: Int
    private let mask: Int
    private let buffer: UnsafeMutablePointer<T>
    
    private let head = ManagedAtomic<Int>(0)
    private let tail = ManagedAtomic<Int>(0)
    
    public init(capacity: Int) {
        var c = 1
        while c < capacity { c <<= 1 }
        self.capacity = c
        self.mask = c - 1
        self.buffer = UnsafeMutablePointer<T>.allocate(capacity: c)
    }
    
    deinit {
        buffer.deallocate()
    }
    
    public func push(_ element: T) -> Bool {
        let currentHead = head.load(ordering: .relaxed)
        let currentTail = tail.load(ordering: .acquiring)
        
        if currentHead - currentTail >= capacity {
            return false
        }
        
        buffer.advanced(by: currentHead & mask).initialize(to: element)
        head.store(currentHead + 1, ordering: .releasing)
        return true
    }
    
    public func pop() -> T? {
        let currentTail = tail.load(ordering: .relaxed)
        let currentHead = head.load(ordering: .acquiring)
        
        if currentTail == currentHead {
            return nil
        }
        
        let element = buffer.advanced(by: currentTail & mask).move()
        tail.store(currentTail + 1, ordering: .releasing)
        return element
    }
    
    public var count: Int {
        let currentHead = head.load(ordering: .relaxed)
        let currentTail = tail.load(ordering: .relaxed)
        return currentHead - currentTail
    }
}
