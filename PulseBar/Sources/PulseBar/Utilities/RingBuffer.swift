struct RingBuffer<Element>: RandomAccessCollection {
  typealias Index = Int

  let capacity: Int

  private var storage: [Element]
  private var oldestStorageIndex = 0

  init(capacity: Int) {
    self.capacity = Swift.max(capacity, 0)
    storage = []
    storage.reserveCapacity(self.capacity)
  }

  var startIndex: Int { 0 }
  var endIndex: Int { storage.count }

  subscript(position: Int) -> Element {
    precondition(indices.contains(position), "Ring buffer index is out of bounds")

    guard storage.count == capacity else {
      return storage[position]
    }
    return storage[(oldestStorageIndex + position) % capacity]
  }

  mutating func append(_ element: Element) {
    guard capacity > 0 else { return }

    if storage.count < capacity {
      storage.append(element)
      return
    }

    storage[oldestStorageIndex] = element
    oldestStorageIndex = (oldestStorageIndex + 1) % capacity
  }
}

extension RingBuffer: Sendable where Element: Sendable {}
