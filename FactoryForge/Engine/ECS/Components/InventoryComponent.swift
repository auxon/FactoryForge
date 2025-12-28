import Foundation

/// Stores items in slots
struct InventoryComponent: Component {
    /// Number of slots
    let slotCount: Int
    
    /// Items in each slot
    var slots: [ItemStack?]

    /// Optional item filter (only allows specific items)
    var filter: ((String) -> Bool)?
    
    init(slots: Int, filter: ((String) -> Bool)? = nil) {
        self.slotCount = slots
        self.slots = Array(repeating: nil, count: slots)
        self.filter = filter
    }
    
    /// Checks if the inventory can accept an item
    func canAccept(itemId: String) -> Bool {
        if let filter = filter, !filter(itemId) {
            return false
        }
        return findSlotFor(itemId: itemId) != nil
    }
    
    /// Finds a slot that can accept the item
    func findSlotFor(itemId: String) -> Int? {
        // First, try to find a slot with the same item that isn't full
        for (index, slot) in slots.enumerated() {
            if let stack = slot, stack.itemId == itemId && stack.count < stack.maxStack {
                return index
            }
        }
        
        // Then, find an empty slot
        for (index, slot) in slots.enumerated() {
            if slot == nil {
                return index
            }
        }
        
        return nil
    }
    
    /// Adds an item to the inventory
    /// - Returns: Number of items that couldn't be added
    @discardableResult
    mutating func add(_ stack: ItemStack) -> Int {
        if let filter = filter, !filter(stack.itemId) {
            return stack.count
        }
        
        var remaining = stack.count
        
        // First, try to fill existing stacks
        for i in 0..<slots.count {
            if var existingStack = slots[i], existingStack.itemId == stack.itemId {
                let space = existingStack.maxStack - existingStack.count
                let toAdd = min(space, remaining)
                existingStack.count += toAdd
                slots[i] = existingStack
                remaining -= toAdd
                
                if remaining == 0 { return 0 }
            }
        }
        
        // Then, use empty slots
        for i in 0..<slots.count {
            if slots[i] == nil {
                let toAdd = min(stack.maxStack, remaining)
                slots[i] = ItemStack(itemId: stack.itemId, count: toAdd, maxStack: stack.maxStack)
                remaining -= toAdd
                
                if remaining == 0 { return 0 }
            }
        }
        
        return remaining
    }
    
    /// Adds a single item
    @discardableResult
    mutating func add(itemId: String, count: Int = 1, maxStack: Int = 100) -> Int {
        return add(ItemStack(itemId: itemId, count: count, maxStack: maxStack))
    }
    
    /// Removes items from the inventory
    /// - Returns: Number of items removed
    @discardableResult
    mutating func remove(itemId: String, count: Int) -> Int {
        var remaining = count
        
        for i in 0..<slots.count {
            if var stack = slots[i], stack.itemId == itemId {
                let toRemove = min(stack.count, remaining)
                stack.count -= toRemove
                remaining -= toRemove
                
                if stack.count == 0 {
                    slots[i] = nil
                } else {
                    slots[i] = stack
                }
                
                if remaining == 0 { return count }
            }
        }
        
        return count - remaining
    }
    
    /// Removes items based on item stacks
    @discardableResult
    mutating func remove(items: [ItemStack]) -> Bool {
        // First check if we have all items
        for item in items {
            if count(of: item.itemId) < item.count {
                return false
            }
        }
        
        // Remove items
        for item in items {
            remove(itemId: item.itemId, count: item.count)
        }
        
        return true
    }
    
    /// Counts items of a specific type
    func count(of itemId: String) -> Int {
        return slots.compactMap { $0 }.filter { $0.itemId == itemId }.reduce(0) { $0 + $1.count }
    }
    
    /// Checks if the inventory has the required items
    func has(items: [ItemStack]) -> Bool {
        for item in items {
            if count(of: item.itemId) < item.count {
                return false
            }
        }
        return true
    }
    
    /// Checks if the inventory has a specific item
    func has(itemId: String, count: Int = 1) -> Bool {
        return self.count(of: itemId) >= count
    }
    
    /// Returns all non-empty slots
    func getAll() -> [ItemStack] {
        return slots.compactMap { $0 }
    }
    
    /// Checks if the inventory is empty
    var isEmpty: Bool {
        return slots.allSatisfy { $0 == nil }
    }
    
    /// Checks if the inventory is full
    var isFull: Bool {
        return slots.allSatisfy { $0 != nil && $0!.count >= $0!.maxStack }
    }
    
    /// Gets the first item in the inventory
    func firstItem() -> ItemStack? {
        return slots.first(where: { $0 != nil }) ?? nil
    }
    
    /// Takes one item from the first available slot
    mutating func takeOne() -> ItemStack? {
        for i in 0..<slots.count {
            if var stack = slots[i] {
                let taken = ItemStack(itemId: stack.itemId, count: 1, maxStack: stack.maxStack)
                stack.count -= 1
                if stack.count == 0 {
                    slots[i] = nil
                } else {
                    slots[i] = stack
                }
                return taken
            }
        }
        return nil
    }

}

/// A stack of items
struct ItemStack: Codable, Equatable {
    var itemId: String
    var count: Int
    var maxStack: Int
    
    init(itemId: String, count: Int = 1, maxStack: Int = 100) {
        self.itemId = itemId
        self.count = count
        self.maxStack = maxStack
    }
    
    var isFull: Bool {
        return count >= maxStack
    }
    
    var isEmpty: Bool {
        return count <= 0
    }
}

// MARK: - Codable support for filter

extension InventoryComponent {
    enum CodingKeys: String, CodingKey {
        case slotCount
        case slots
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slotCount = try container.decode(Int.self, forKey: .slotCount)
        slots = try container.decode([ItemStack?].self, forKey: .slots)
        filter = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(slotCount, forKey: .slotCount)
        try container.encode(slots, forKey: .slots)
    }
}

