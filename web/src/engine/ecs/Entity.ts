export type EntityId = number;

export interface Entity {
  id: EntityId;
  generation: number;
}

export function entityKey(e: Entity): string {
  return `${e.id}:${e.generation}`;
}

export function entitiesEqual(a: Entity, b: Entity): boolean {
  return a.id === b.id && a.generation === b.generation;
}

export class EntityManager {
  private generations: number[] = [];
  private freeList: number[] = [];
  private alive = new Set<number>();

  create(): Entity {
    let id: number;
    if (this.freeList.length > 0) {
      id = this.freeList.pop()!;
    } else {
      id = this.generations.length;
      this.generations.push(0);
    }
    this.alive.add(id);
    return { id, generation: this.generations[id]! };
  }

  destroy(entity: Entity): void {
    if (!this.isAlive(entity)) return;
    this.alive.delete(entity.id);
    this.generations[entity.id] = (this.generations[entity.id] ?? 0) + 1;
    this.freeList.push(entity.id);
  }

  isAlive(entity: Entity): boolean {
    return this.alive.has(entity.id) && this.generations[entity.id] === entity.generation;
  }

  get entities(): Entity[] {
    return [...this.alive].map((id) => ({ id, generation: this.generations[id]! }));
  }

  get count(): number {
    return this.alive.size;
  }
}
