// Per-frame audio feature extraction matching the original ALF-based gameplay.
//
// Original ALF supplied two values per frame plus a pitch bin. The game then
// applied a per-song normalization: it observed the audio for a warm-up
// window, computed the average flux/intensity, and scaled subsequent readings
// so that arbitrary songs all hit the same gameplay thresholds.
//
// gameAudioStuff.as constants we replicate semantically:
//   FPS = 30
//   START_COUNT_SECONDS = 15  // ignore the first 15s entirely
//   END_COUNT_SECONDS   = 20  // accumulate stats during [15s, 20s]; lock at 20s
//   TARGET_AVG_FLUX      = 27000  // raw target; stored values were /1000
//   TARGET_AVG_INTENSITY = 5000   // raw target; stored values were /10
//
// We normalize so that post-warmup flux and intensity both average to 1.0,
// which makes the original gameplay constants transplant as ratios:
//   LO_FLUX  ≈ 0.37   // (10000  / 27000)
//   HI_FLUX  ≈ 2.2    // (60000  / 27000)
//   BEAT_FLUX≈ 3.7    // (100000 / 27000)
//   LO_INT   ≈ 0.08   // (400    / 5000)
//   HI_INT   ≈ 1.6    // (8000   / 5000)
//
// Peak detection mirrors gameAudioStuff.as `isPeak`: a 3-point local maximum
// (x[t-1] < x[t] > x[t+1]). We report it with one frame of lag — the value at
// frame t is flagged on frame t+1 once we know what comes next.

export interface FrameFeatures {
  /** Frame index since engine start. */
  frame: number;
  /** Seconds of audio observed so far (frame / sampleRateFps). */
  elapsedSec: number;

  /** Spectral flux for the previous frame, post-normalization. */
  flux: number;
  /** Pre-normalization raw flux (for debugging / threshold tuning). */
  fluxRaw: number;
  /** True if the previous-previous frame's flux is a 3-point local max. */
  fluxPeak: boolean;

  /** Intensity (sum of linear magnitudes) for the previous frame, normalized. */
  intensity: number;
  intensityRaw: number;
  intensityPeak: boolean;

  /** Pitch bin 0..36 for previous frame (low E2 .. ~E5, 4-octave fold). -1 if too quiet. */
  pitch: number;
  /** Raw dominant frequency (Hz) of previous frame. */
  dominantHz: number;

  /** Coarse loudness 0..1 (max bin magnitude). Useful for visuals. */
  level: number;

  /** True after the 20-second normalization lock-in. */
  normalized: boolean;
}

export interface EngineOptions {
  fftSize?: number;
  smoothing?: number;
  /** Below this max-bin magnitude, pitch is suppressed (-1). */
  pitchSilenceLevel?: number;
  /** Effective frame rate the consumer pulls features at (Hz). Default 60. */
  fps?: number;
  /** Seconds of warmup before stats accumulate. */
  warmupSec?: number;
  /** Seconds at which to lock in the normalization. Must be > warmupSec. */
  lockInSec?: number;
  /** Target average for normalized flux. */
  targetFluxAvg?: number;
  /** Target average for normalized intensity. */
  targetIntensityAvg?: number;
}

const DEFAULTS = {
  fftSize: 2048,
  smoothing: 0,
  pitchSilenceLevel: 0.02,
  fps: 60,
  warmupSec: 15,
  lockInSec: 20,
  targetFluxAvg: 1.0,
  targetIntensityAvg: 1.0,
};

export class AudioFeatureEngine {
  readonly ctx: AudioContext;
  readonly analyser: AnalyserNode;
  readonly input: GainNode;

  private fftSize: number;
  private binCount: number;
  private dbBuf: Float32Array<ArrayBuffer>;
  private prevLin: Float32Array<ArrayBuffer>;
  private curLin: Float32Array<ArrayBuffer>;
  private hasPrev = false;
  private monitorGain: GainNode;
  private destinationConnected = false;

  // 1-frame-lag ring for 3-point peak detection on flux and intensity:
  // when we compute frame t, we report whether frame t-1's value is a peak
  // (i.e. greater than frame t-2's and frame t's).
  private prevPrevFlux = 0;
  private prevFlux = 0;
  private prevPrevInt = 0;
  private prevInt = 0;
  private prevPitch = -1;
  private prevDominantHz = 0;
  private prevLevel = 0;

  private fps: number;
  private warmupSec: number;
  private lockInSec: number;
  private targetFluxAvg: number;
  private targetIntensityAvg: number;
  private pitchSilence: number;

  // Adaptive normalization state.
  private statFrames = 0;       // frames seen during [warmup, lockIn)
  private fluxSum = 0;
  private intSum = 0;
  private adjustFlux = 1;
  private adjustInt = 1;
  private locked = false;

  private frameCounter = 0;

  constructor(ctx: AudioContext, opts: EngineOptions = {}) {
    this.ctx = ctx;
    this.fftSize = opts.fftSize ?? DEFAULTS.fftSize;
    this.pitchSilence = opts.pitchSilenceLevel ?? DEFAULTS.pitchSilenceLevel;
    this.fps = opts.fps ?? DEFAULTS.fps;
    this.warmupSec = opts.warmupSec ?? DEFAULTS.warmupSec;
    this.lockInSec = opts.lockInSec ?? DEFAULTS.lockInSec;
    this.targetFluxAvg = opts.targetFluxAvg ?? DEFAULTS.targetFluxAvg;
    this.targetIntensityAvg = opts.targetIntensityAvg ?? DEFAULTS.targetIntensityAvg;

    this.analyser = ctx.createAnalyser();
    this.analyser.fftSize = this.fftSize;
    this.analyser.smoothingTimeConstant = opts.smoothing ?? DEFAULTS.smoothing;
    this.analyser.minDecibels = -100;
    this.analyser.maxDecibels = -10;

    this.binCount = this.analyser.frequencyBinCount;
    this.dbBuf = new Float32Array(new ArrayBuffer(this.binCount * 4));
    this.prevLin = new Float32Array(new ArrayBuffer(this.binCount * 4));
    this.curLin = new Float32Array(new ArrayBuffer(this.binCount * 4));

    this.input = ctx.createGain();
    this.monitorGain = ctx.createGain();
    this.input.connect(this.analyser);
    this.input.connect(this.monitorGain);
  }

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
    this.prevPrevFlux = this.prevFlux = 0;
    this.prevPrevInt = this.prevInt = 0;
    this.prevPitch = -1;
    this.prevDominantHz = 0;
    this.prevLevel = 0;
    this.statFrames = 0;
    this.fluxSum = 0;
    this.intSum = 0;
    this.adjustFlux = 1;
    this.adjustInt = 1;
    this.locked = false;
    this.frameCounter = 0;
  }

  /** Adaptive normalization progress: 0..1 within [warmupSec, lockInSec], 1 once locked. */
  normalizationProgress(): number {
    if (this.locked) return 1;
    const t = this.frameCounter / this.fps;
    if (t < this.warmupSec) return 0;
    if (t >= this.lockInSec) return 1;
    return (t - this.warmupSec) / (this.lockInSec - this.warmupSec);
  }

  tick(): FrameFeatures {
    this.analyser.getFloatFrequencyData(this.dbBuf);

    let level = 0;
    let intensityRaw = 0;
    let maxBin = 0;
    let maxMag = 0;
    for (let i = 0; i < this.binCount; i++) {
      const db = this.dbBuf[i];
      const lin = db <= -100 ? 0 : Math.pow(10, db / 20);
      this.curLin[i] = lin;
      intensityRaw += lin;
      if (lin > maxMag) { maxMag = lin; maxBin = i; }
      if (lin > level) level = lin;
    }

    let fluxRaw = 0;
    if (this.hasPrev) {
      for (let i = 0; i < this.binCount; i++) {
        const d = this.curLin[i] - this.prevLin[i];
        if (d > 0) fluxRaw += d;
      }
    }

    const dominantHz = (maxBin * this.ctx.sampleRate) / this.fftSize;
    const pitch = level < this.pitchSilence ? -1 : foldPitch(dominantHz);

    // Swap prev/cur buffers (avoid allocation).
    const swap = this.prevLin;
    this.prevLin = this.curLin;
    this.curLin = swap;
    this.hasPrev = true;

    // Accumulate stats during the warmup window.
    const elapsed = this.frameCounter / this.fps;
    if (elapsed >= this.warmupSec && !this.locked) {
      this.statFrames++;
      this.fluxSum += fluxRaw;
      this.intSum += intensityRaw;
      if (elapsed >= this.lockInSec && this.statFrames > 0) {
        const avgFlux = this.fluxSum / this.statFrames;
        const avgInt = this.intSum / this.statFrames;
        this.adjustFlux = avgFlux > 0 ? this.targetFluxAvg / avgFlux : 1;
        this.adjustInt = avgInt > 0 ? this.targetIntensityAvg / avgInt : 1;
        this.locked = true;
      }
    }

    const fluxNorm = fluxRaw * this.adjustFlux;
    const intNorm = intensityRaw * this.adjustInt;

    // Peak refers to the *previous* normalized value.
    const fluxPeak = this.prevFlux > this.prevPrevFlux && this.prevFlux > fluxNorm;
    const intensityPeak = this.prevInt > this.prevPrevInt && this.prevInt > intNorm;

    const out: FrameFeatures = {
      frame: this.frameCounter,
      elapsedSec: elapsed,
      flux: this.prevFlux,
      fluxRaw: this.prevFlux / Math.max(this.adjustFlux, 1e-12),
      fluxPeak,
      intensity: this.prevInt,
      intensityRaw: this.prevInt / Math.max(this.adjustInt, 1e-12),
      intensityPeak,
      pitch: this.prevPitch,
      dominantHz: this.prevDominantHz,
      level: this.prevLevel,
      normalized: this.locked,
    };

    // Shift the rings forward.
    this.prevPrevFlux = this.prevFlux;
    this.prevFlux = fluxNorm;
    this.prevPrevInt = this.prevInt;
    this.prevInt = intNorm;
    this.prevPitch = pitch;
    this.prevDominantHz = dominantHz;
    this.prevLevel = level;
    this.frameCounter++;

    return out;
  }
}

/**
 * Mirrors gameAudioStuff.as `findPitch`: fold into [82.41, ~659.28) Hz
 * (4 octaves above E2) and quantize to 37 steps of ~33 cents each.
 */
export function foldPitch(hz: number): number {
  if (!isFinite(hz) || hz <= 0) return -1;
  const LOW = 82.41;
  const HIGH = 164.82 * 4;
  let f = hz;
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
