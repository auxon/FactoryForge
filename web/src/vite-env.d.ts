/// <reference types="vite/client" />

declare module 'three/webgpu' {
  // Runtime module; typed loosely so createRenderer can import it.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const mod: any;
  export = mod;
}
