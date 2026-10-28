#!/usr/bin/env python3
"""tools/audio/gen_yawn.py — bostezos sintéticos del guardia (FEAT-029, heist.md R5).

Voz «aaah» por síntesis de formantes: tren de pulsos glotales con el tono subiendo y bajando,
filtrado por los formantes de la vocal /a/, con envolvente de bostezo y un soplo de aire al
final. Reproducible (semilla fija). Escribe assets/audio/sfx/voice/yawn_NNN.ogg con ffmpeg.

Uso: python3 tools/audio/gen_yawn.py
"""

import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

RATE = 44100
OUT_DIR = Path(__file__).resolve().parents[2] / "assets" / "audio" / "sfx" / "voice"
# (tono inicial, pico, final en Hz; duración en s) por variante
VARIANTS = [(120.0, 175.0, 95.0, 1.7), (135.0, 190.0, 105.0, 1.4), (110.0, 160.0, 90.0, 1.9)]
FORMANTS = [(700.0, 110.0, 1.0), (1150.0, 120.0, 0.55), (2500.0, 160.0, 0.25)]


def resonator(signal: np.ndarray, freq: float, bandwidth: float) -> np.ndarray:
    r = np.exp(-np.pi * bandwidth / RATE)
    a1 = -2.0 * r * np.cos(2.0 * np.pi * freq / RATE)
    a2 = r * r
    out = np.zeros_like(signal)
    y1 = y2 = 0.0
    for i, x in enumerate(signal):
        y = x - a1 * y1 - a2 * y2
        out[i] = y
        y2, y1 = y1, y
    return out


def yawn(f_start: float, f_peak: float, f_end: float, seconds: float, rng) -> np.ndarray:
    n = int(seconds * RATE)
    t = np.linspace(0.0, 1.0, n)
    pitch = np.where(
        t < 0.35, f_start + (f_peak - f_start) * (t / 0.35), f_peak + (f_end - f_peak) * ((t - 0.35) / 0.65)
    )
    phase = np.cumsum(pitch / RATE)
    pulses = (np.diff(np.floor(phase), prepend=0.0) > 0).astype(float)
    source = np.convolve(pulses, np.hanning(64), mode="same") + 0.04 * rng.standard_normal(n)
    voice = sum(gain * resonator(source, f, bw) for f, bw, gain in FORMANTS)
    env = np.minimum(1.0, t / 0.15) * np.clip((1.0 - t) / 0.45, 0.0, 1.0) ** 0.8
    breath = resonator(rng.standard_normal(n), 1400.0, 900.0) * np.clip((t - 0.7) / 0.3, 0.0, 1.0)
    mix = voice * env + 0.25 * breath * (1.0 - t)
    return mix / (np.max(np.abs(mix)) + 1e-9) * 0.8


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(1984)
    for index, (f0, fp, f1, secs) in enumerate(VARIANTS):
        samples = (yawn(f0, fp, f1, secs, rng) * 32767).astype(np.int16)
        with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
            with wave.open(tmp.name, "wb") as wav:
                wav.setnchannels(1)
                wav.setsampwidth(2)
                wav.setframerate(RATE)
                wav.writeframes(samples.tobytes())
            out = OUT_DIR / f"yawn_{index:03d}.ogg"
            subprocess.run(
                ["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "4", str(out)],
                check=True,
            )
            print(out)


if __name__ == "__main__":
    main()
