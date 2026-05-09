// Per-frame audio feature extraction matching the original ALF-based gameplay.
//
// Original ALF (gameAudioStuff.as) supplied two values per frame:
//   FLUX_VAL  — spectral flux: sum over bins of max(0, mag[t] - mag[t-1])
//   PITCH     — dominant frequency folded into [82.41 Hz, 659.28 Hz] and
//               quantized to one of 37 steps (0..36, ~3 cents each)
//
// Peak detection in the original is a 3-point local max: x[i] > x[i-1] && x[i] > x[i+1].
// We replicate that with a 1-frame delay (we report the peak at frame t once frame t+1 arrives).

export interface FrameFeatures {
  /** Frame index since engine start. */
  frame: number;
  /** Spectral flux this frame (sum of positive bin-to-bin magnitude diffs). */
  flux: number;
  /** True if the *previous* frame's flux is a 3-point local max. */
  fluxPeak: boolean;
  /** Pitch bin 0..36 (low E to ~E5 folded to 4 octaves), or -1 if too quiet. */
  pitch: number;
  /** Raw frequency in Hz of the dominant bin (pre-folding). */
  dominantHz: number;
  /** Coarse loudness 0..1 (max bin magnitude). */
  level: number;
}

export interface EngineOptions {
  fftSize?: number;
  /** Smoothing on the analyser. 0 = no smoothing, 0.8 = heavy. */
  smoothing?: number;
  /** Below this level the pitch bin is suppressed (returned as -1). */
  pitchSilenceLevel?: number;
}

export class AudioFeatureEngine {
  readonly ctx: AudioContext;
  readonly analyser: AnalyserNode;
  /** Connect your source here; engine handles routing to destination if `monitor` is true. */
  readonly input: GainNode;

  private fftSize: number;
  private binCount: number;
  // Use Float32Array<ArrayBuffer> (not ArrayBufferLike) so getFloatFrequencyData accepts it
  // under TS 5.7+ DOM lib typings.
  private dbBuf: Float32Array<ArrayBuffer>;
  private prevLin: Float32Array<ArrayBuffer>;
  private curLin: Float32Array<ArrayBuffer>;
  private hasPrev = false;
  private monitorGain: GainNode;
  private destinationConnected = false;

  // Two-frame ring for 3-point peak detection:
  // when we compute frame t, the buffered "prev" (t-1) becomes a peak if
  // prevFlux > prevPrevFlux && prevFlux > curFlux.
  private prevPrevFlux = 0;
  private prevFlux = 0;
  private prevPitch = -1;
  private prevDominantHz = 0;
  private prevLevel = 0;

  private frameCounter = 0;
  private pitchSilence: number;

  constructor(ctx: AudioContext, opts: EngineOptions = {}) {
    this.ctx = ctx;
    this.fftSize = opts.fftSize ?? 2048;
    this.pitchSilence = opts.pitchSilenceLevel ?? 0.02;

    this.analyser = ctx.createAnalyser();
    this.analyser.fftSize = this.fftSize;
    this.analyser.smoothingTimeConstant = opts.smoothing ?? 0.0;
    this.analyser.minDecibels = -100;
    this.analyser.maxDecibels = -10;

    this.binCount = this.analyser.frequencyBinCount;
    this.dbBuf = new Float32Array(new ArrayBuffer(this.binCount * 4));
    this.prevLin = new Float32Array(new ArrayBuffer(this.binCount * 4));
    this.curLin = new Float32Array(new ArrayBuffer(this.binCount * 4));

    this.input = ctx.createGain();
    this.input.gain.value = 1;
    this.monitorGain = ctx.createGain();
    this.monitorGain.gain.value = 1;

    this.input.connect(this.analyser);
    this.input.connect(this.monitorGain);
  }

  /** Route audio to speakers. Off by default for mic to prevent feedback. */
  setMonitor(on: boolean) {
    if (on && !this.destinationConnected) {
      this.monitorGain.connect(this.ctx.destination);
      this.destinationConnected = true;
    } else if (!on && this.destinationConnected) {
      this.monitorGain.disconnect(this.ctx.destination);
      this.destinationConnected = false;
    }
  }

  reset() {
    this.hasPrev = false;
    this.prevPrevFlux = 0;
    this.prevFlux = 0;
    this.prevPitch = -1;
    this.prevDominantHz = 0;
    this.prevLevel = 0;
    this.frameCounter = 0;
  }

  /**
   * Pull one frame of features. Call once per render frame.
   * The returned `flux` is for *this* frame; `fluxPeak` refers to the previous
   * frame (3-point peak detection has 1 frame of lag). `pitch`/`dominantHz`
   * are also for the previous frame so they line up with `fluxPeak`.
   */
  tick(): FrameFeatures {
    this.analyser.getFloatFrequencyData(this.dbBuf);

    // dB → linear magnitude
    let level = 0;
    let maxBin = 0;
    let maxMag = 0;
    for (let i = 0; i < this.binCount; i++) {
      // Web Audio reports -Infinity for silence; clamp.
      const db = this.dbBuf[i];
      const lin = db <= -100 ? 0 : Math.pow(10, db / 20);
      this.curLin[i] = lin;
      if (lin > maxMag) { maxMag = lin; maxBin = i; }
      if (lin > level) level = lin;
    }

    // Spectral flux: sum of positive bin-to-bin diffs vs previous frame.
    let flux = 0;
    if (this.hasPrev) {
      for (let i = 0; i < this.binCount; i++) {
        const d = this.curLin[i] - this.prevLin[i];
        if (d > 0) flux += d;
      }
    }

    const dominantHz = (maxBin * this.ctx.sampleRate) / this.fftSize;
    const pitch = level < this.pitchSilence ? -1 : foldPitch(dominantHz);

    // Swap prev/cur buffers (avoid allocation).
    const swap = this.prevLin;
    this.prevLin = this.curLin;
    this.curLin = swap;
    this.hasPrev = true;

    // Peak refers to the *previous* flux value: prev > prevPrev && prev > current.
    const fluxPeak = this.prevFlux > this.prevPrevFlux && this.prevFlux > flux;

    const out: FrameFeatures = {
      frame: this.frameCounter,
      flux: this.prevFlux,
      fluxPeak,
      pitch: this.prevPitch,
      dominantHz: this.prevDominantHz,
      level: this.prevLevel,
    };

    // Shift the ring forward.
    this.prevPrevFlux = this.prevFlux;
    this.prevFlux = flux;
    this.prevPitch = pitch;
    this.prevDominantHz = dominantHz;
    this.prevLevel = level;
    this.frameCounter++;

    return out;
  }
}

/**
 * Mirrors gameAudioStuff.as `findPitch`: fold into [82.41, 659.28) Hz
 * (4 octaves above low E2) and quantize to 37 steps of ~33 cents each.
 */
export function foldPitch(hz: number): number {
  if (!isFinite(hz) || hz <= 0) return -1;
  const LOW = 82.41; // E2
  const HIGH = 164.82 * 4; // ~E5
  let f = hz;
  // Bring into range by octave shifts.
  while (f < LOW) f *= 2;
  while (f >= HIGH) f *= 0.5;
  let bestStep = 0;
  let bestDist = Infinity;
  for (let step = 0; step < 37; step++) {
    const d = Math.abs(f - LOW * Math.pow(2, step / 36));
    if (d < bestDist) { bestDist = d; bestStep = step; }
  }
  return bestStep;
}
