import type { GameSave } from '@shared/save/types';

const PREFIX = 'ff-save-';

export function listSaves(): string[] {
  const keys: string[] = [];
  for (let i = 0; i < localStorage.length; i++) {
    const k = localStorage.key(i);
    if (k?.startsWith(PREFIX)) keys.push(k.slice(PREFIX.length));
  }
  return keys.sort();
}

export function writeSave(slot: string, save: GameSave): void {
  localStorage.setItem(PREFIX + slot, JSON.stringify(save));
}

export function readSave(slot: string): GameSave | null {
  const raw = localStorage.getItem(PREFIX + slot);
  if (!raw) return null;
  return JSON.parse(raw) as GameSave;
}

export function deleteSave(slot: string): void {
  localStorage.removeItem(PREFIX + slot);
}
