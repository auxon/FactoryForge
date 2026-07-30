import * as THREE from 'three';

export type GameRenderer = {
  setPixelRatio(n: number): void;
  setSize(w: number, h: number, updateStyle?: boolean): void;
  render(scene: THREE.Scene, camera: THREE.Camera): void;
  dispose(): void;
  outputColorSpace: string;
  domElement: HTMLCanvasElement;
};

/** Prefer WebGPURenderer (three/webgpu) with automatic WebGL2 fallback. */
export async function createRenderer(canvas: HTMLCanvasElement, antialias: boolean): Promise<GameRenderer> {
  try {
    const webgpu = await import('three/webgpu');
    const RendererCtor = (webgpu as { WebGPURenderer: new (p: unknown) => GameRenderer & { init(): Promise<void> } })
      .WebGPURenderer;
    const renderer = new RendererCtor({ canvas, antialias });
    await renderer.init();
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    return renderer;
  } catch {
    const renderer = new THREE.WebGLRenderer({ canvas, antialias, alpha: false });
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    return renderer;
  }
}
