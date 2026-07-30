/** Lightweight Web Audio hooks for place/mine/shoot feedback. */
export class AudioManager {
  private ctx: AudioContext | null = null;
  enabled = true;

  private ensure(): AudioContext | null {
    if (!this.enabled || typeof AudioContext === 'undefined') return null;
    if (!this.ctx) this.ctx = new AudioContext();
    return this.ctx;
  }

  private beep(freq: number, dur = 0.05, type: OscillatorType = 'square', gain = 0.03): void {
    const ctx = this.ensure();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.type = type;
    osc.frequency.value = freq;
    g.gain.value = gain;
    osc.connect(g);
    g.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + dur);
  }

  place(): void {
    this.beep(440, 0.04);
  }
  mine(): void {
    this.beep(220, 0.03, 'triangle');
  }
  shoot(): void {
    this.beep(880, 0.06, 'sawtooth', 0.02);
  }
  ui(): void {
    this.beep(660, 0.03, 'sine');
  }
}

export const audio = new AudioManager();
