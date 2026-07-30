export interface GameSave {
  version: number;
  seed: number;
  playTime: number;
  playerData: {
    position: { x: number; y: number };
    inventory: { slots: Array<{ itemId: string | null; count: number }> };
    health: number;
  };
  worldData: { entities: Array<{ id: number; generation: number; components: Record<string, unknown> }> };
  researchData: {
    currentResearchId: string | null;
    progress: Record<string, number>;
    completed: string[];
    unlockedRecipes: string[];
  };
  chunks: unknown[];
  timestamp: string;
}
