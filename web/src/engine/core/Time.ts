export class Time {
  totalTime = 0;
  deltaTime = 0;
  unscaledDeltaTime = 0;
  frameCount = 0;
  serverTick = 0;
  fixedDeltaTime = 1 / 60;
  deterministicDeltaTime = 1 / 60;
  isDeterministic = false;
  timeScale = 1;
  private accumulator = 0;
  private lastFrameTime = performance.now() / 1000;
  private readonly maxDeltaTime = 1 / 30;
  private alpha = 0;

  get isPaused(): boolean {
    return this.timeScale === 0;
  }
  set isPaused(v: boolean) {
    this.timeScale = v ? 0 : 1;
  }

  get fixedUpdateAlpha(): number {
    return this.alpha;
  }

  update(): void {
    const now = performance.now() / 1000;
    this.unscaledDeltaTime = Math.min(now - this.lastFrameTime, this.maxDeltaTime);
    this.lastFrameTime = now;
    this.deltaTime = this.unscaledDeltaTime * this.timeScale;
    this.totalTime += this.deltaTime;
    this.frameCount++;
    this.accumulator += this.deltaTime;
  }

  updateDeterministic(): void {
    this.unscaledDeltaTime = Math.min(this.deterministicDeltaTime, this.maxDeltaTime);
    this.deltaTime = this.unscaledDeltaTime * this.timeScale;
    this.totalTime += this.deltaTime;
    this.frameCount++;
    this.serverTick++;
    this.accumulator += this.deltaTime;
  }

  consumeFixedUpdate(): boolean {
    if (this.accumulator >= this.fixedDeltaTime) {
      this.accumulator -= this.fixedDeltaTime;
      this.alpha = this.accumulator / this.fixedDeltaTime;
      return true;
    }
    this.alpha = this.accumulator / this.fixedDeltaTime;
    return false;
  }

  reset(): void {
    this.totalTime = 0;
    this.deltaTime = 0;
    this.accumulator = 0;
    this.frameCount = 0;
    this.serverTick = 0;
    this.lastFrameTime = performance.now() / 1000;
  }
}

export const gameTime = new Time();
