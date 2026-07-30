import type { Entity } from './Entity';

/** Sparse-set component store */
export class ComponentStore<T> {
  private dense: T[] = [];
  private entities: Entity[] = [];
  private sparse = new Map<number, number>();

  set(component: T, entity: Entity): void {
    const idx = this.sparse.get(entity.id);
    if (idx !== undefined && this.entities[idx]?.generation === entity.generation) {
      this.dense[idx] = component;
      return;
    }
    const newIdx = this.dense.length;
    this.dense.push(component);
    this.entities.push(entity);
    this.sparse.set(entity.id, newIdx);
  }

  get(entity: Entity): T | undefined {
    const idx = this.sparse.get(entity.id);
    if (idx === undefined) return undefined;
    const e = this.entities[idx];
    if (!e || e.generation !== entity.generation) return undefined;
    return this.dense[idx];
  }

  has(entity: Entity): boolean {
    return this.get(entity) !== undefined;
  }

  remove(entity: Entity): void {
    const idx = this.sparse.get(entity.id);
    if (idx === undefined) return;
    const e = this.entities[idx];
    if (!e || e.generation !== entity.generation) return;

    const last = this.dense.length - 1;
    if (idx !== last) {
      this.dense[idx] = this.dense[last]!;
      this.entities[idx] = this.entities[last]!;
      this.sparse.set(this.entities[idx]!.id, idx);
    }
    this.dense.pop();
    this.entities.pop();
    this.sparse.delete(entity.id);
  }

  forEach(fn: (component: T, entity: Entity) => void): void {
    for (let i = 0; i < this.dense.length; i++) {
      fn(this.dense[i]!, this.entities[i]!);
    }
  }

  entries(): Array<{ entity: Entity; component: T }> {
    const out: Array<{ entity: Entity; component: T }> = [];
    for (let i = 0; i < this.dense.length; i++) {
      out.push({ entity: this.entities[i]!, component: this.dense[i]! });
    }
    return out;
  }

  get size(): number {
    return this.dense.length;
  }
}
