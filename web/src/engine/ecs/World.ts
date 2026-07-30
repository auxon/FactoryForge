import { EntityManager, type Entity } from './Entity';
import { ComponentStore } from './ComponentStore';
import type { PositionComponent } from '../../game/components';

export class World {
  private entityManager = new EntityManager();
  private stores = new Map<string, ComponentStore<unknown>>();
  private spatialIndex = new Map<string, Entity>();
  private pendingDespawns: Entity[] = [];

  spawn(): Entity {
    return this.entityManager.create();
  }

  spawnWith(): EntityBuilder {
    return new EntityBuilder(this.spawn(), this);
  }

  despawn(entity: Entity): void {
    if (!this.entityManager.isAlive(entity)) return;
    const pos = this.getByName<PositionComponent>('position', entity);
    if (pos) this.spatialIndex.delete(tileKey(pos.tileX, pos.tileY));
    for (const store of this.stores.values()) store.remove(entity);
    this.entityManager.destroy(entity);
  }

  despawnDeferred(entity: Entity): void {
    this.pendingDespawns.push(entity);
  }

  processPending(): void {
    for (const e of this.pendingDespawns) this.despawn(e);
    this.pendingDespawns.length = 0;
  }

  isAlive(entity: Entity): boolean {
    return this.entityManager.isAlive(entity);
  }

  get entities(): Entity[] {
    return this.entityManager.entities;
  }

  get entityCount(): number {
    return this.entityManager.count;
  }

  private store<T>(name: string): ComponentStore<T> {
    let s = this.stores.get(name) as ComponentStore<T> | undefined;
    if (!s) {
      s = new ComponentStore<T>();
      this.stores.set(name, s as ComponentStore<unknown>);
    }
    return s;
  }

  addByName<T>(name: string, component: T, entity: Entity): void {
    if (name === 'position') {
      const old = this.getByName<PositionComponent>('position', entity);
      if (old) this.spatialIndex.delete(tileKey(old.tileX, old.tileY));
    }
    this.store<T>(name).set(component, entity);
    if (name === 'position') {
      const p = component as PositionComponent;
      this.spatialIndex.set(tileKey(p.tileX, p.tileY), entity);
    }
  }

  getByName<T>(name: string, entity: Entity): T | undefined {
    return this.store<T>(name).get(entity);
  }

  hasByName(name: string, entity: Entity): boolean {
    return this.store(name).has(entity);
  }

  removeByName(name: string, entity: Entity): void {
    if (name === 'position') {
      const old = this.getByName<PositionComponent>('position', entity);
      if (old) this.spatialIndex.delete(tileKey(old.tileX, old.tileY));
    }
    this.store(name).remove(entity);
  }

  forEach<T>(name: string, fn: (component: T, entity: Entity) => void): void {
    this.store<T>(name).forEach(fn);
  }

  entries<T>(name: string): Array<{ entity: Entity; component: T }> {
    return this.store<T>(name).entries();
  }

  entityAt(tileX: number, tileY: number): Entity | undefined {
    return this.spatialIndex.get(tileKey(tileX, tileY));
  }

  updatePosition(entity: Entity, tileX: number, tileY: number, offsetX = 0.5, offsetY = 0.5): void {
    const old = this.getByName<PositionComponent>('position', entity);
    if (old) this.spatialIndex.delete(tileKey(old.tileX, old.tileY));
    const next: PositionComponent = { tileX, tileY, offsetX, offsetY };
    this.store<PositionComponent>('position').set(next, entity);
    this.spatialIndex.set(tileKey(tileX, tileY), entity);
  }

  clear(): void {
    for (const e of [...this.entityManager.entities]) this.despawn(e);
    this.spatialIndex.clear();
    this.stores.clear();
  }

  serializeEntities(): Array<{ id: number; generation: number; components: Record<string, unknown> }> {
    const out: Array<{ id: number; generation: number; components: Record<string, unknown> }> = [];
    for (const entity of this.entityManager.entities) {
      const components: Record<string, unknown> = {};
      for (const [name, store] of this.stores) {
        const c = store.get(entity);
        if (c !== undefined) components[name] = c;
      }
      out.push({ id: entity.id, generation: entity.generation, components });
    }
    return out;
  }
}

export class EntityBuilder {
  constructor(
    private entity: Entity,
    private world: World,
  ) {}

  with(name: string, component: unknown): this {
    this.world.addByName(name, component, this.entity);
    return this;
  }

  build(): Entity {
    return this.entity;
  }
}

export function tileKey(x: number, y: number): string {
  return `${x},${y}`;
}
