// Inventory model. Ported from InventoryComponent.swift + ItemStack.
import { ITEM_MAP } from '../data/items';

export interface Slot { itemId: string; count: number; }

export class Inventory {
  slots: (Slot | null)[];
  constructor(public slotCount: number, slots?: (Slot | null)[]) {
    this.slots = slots ?? new Array(slotCount).fill(null);
    while (this.slots.length < slotCount) this.slots.push(null);
  }
  maxStack(itemId: string): number {
    return ITEM_MAP.get(itemId)?.stackSize ?? 100;
  }
  count(itemId: string): number {
    let n = 0;
    for (const s of this.slots) if (s && s.itemId === itemId) n += s.count;
    return n;
  }
  has(items: { itemId: string; count: number }[]): boolean {
    return items.every((r) => this.count(r.itemId) >= r.count);
  }
  canAccept(itemId: string, count = 1): boolean {
    const max = this.maxStack(itemId);
    let room = 0;
    for (const s of this.slots) {
      if (!s) room += max;
      else if (s.itemId === itemId) room += max - s.count;
      if (room >= count) return true;
    }
    return room >= count;
  }
  /** Add items. Returns leftover count. */
  add(itemId: string, count: number): number {
    const max = this.maxStack(itemId);
    for (const s of this.slots) {
      if (count <= 0) break;
      if (s && s.itemId === itemId && s.count < max) {
        const take = Math.min(max - s.count, count);
        s.count += take; count -= take;
      }
    }
    for (let i = 0; i < this.slots.length && count > 0; i++) {
      if (!this.slots[i]) {
        const take = Math.min(max, count);
        this.slots[i] = { itemId, count: take }; count -= take;
      }
    }
    return count;
  }
  remove(itemId: string, count: number): number {
    let removed = 0;
    for (let i = 0; i < this.slots.length && count > 0; i++) {
      const s = this.slots[i];
      if (s && s.itemId === itemId) {
        const take = Math.min(s.count, count);
        s.count -= take; count -= take; removed += take;
        if (s.count <= 0) this.slots[i] = null;
      }
    }
    return removed;
  }
  takeOne(itemId: string): boolean {
    return this.remove(itemId, 1) === 1;
  }
  serialize(): (Slot | null)[] { return this.slots; }
  static deserialize(slotCount: number, slots: (Slot | null)[]): Inventory {
    return new Inventory(slotCount, slots);
  }
}
