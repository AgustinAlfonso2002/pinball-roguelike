"""Genera los efectos de sonido retro del prototipo (assets/sfx/*.wav).

Uso:  python tools/gen_sfx.py
Requiere numpy. Son sonidos provisorios sintetizados; después se reemplazan
por los definitivos sin tocar el código (mismos nombres de archivo).
"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
rng = np.random.default_rng(1)


def t(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.002, decay_pow=2.0):
    x = np.linspace(0, 1, n)
    a = max(1, int(SR * attack))
    e = (1 - x) ** decay_pow
    e[:a] *= np.linspace(0, 1, a)
    return e


def square(freq, tt):
    phase = np.cumsum(np.broadcast_to(freq, tt.shape) / SR)
    return np.sign(np.sin(2 * np.pi * phase))


def sine(freq, tt):
    phase = np.cumsum(np.broadcast_to(freq, tt.shape) / SR)
    return np.sin(2 * np.pi * phase)


def saw(freq, tt):
    phase = np.cumsum(np.broadcast_to(freq, tt.shape) / SR)
    return 2 * (phase % 1) - 1


def noise(n):
    return rng.uniform(-1, 1, n)


def lowpass(x, alpha):
    """Filtro pasa bajos de un polo; alpha puede ser fijo o variar en el tiempo."""
    alphas = np.broadcast_to(alpha, x.shape)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alphas[i] * (v - acc)
        y[i] = acc
    return y


def save(name, x, gain=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main():
    os.makedirs(OUT, exist_ok=True)

    tt = t(0.07)
    x = lowpass(noise(len(tt)), 0.25) * env(len(tt), decay_pow=4) + 0.8 * sine(110 * np.exp(-tt * 20), tt) * env(len(tt), decay_pow=3)
    save("flipper_up", x, 0.75)

    tt = t(0.05)
    x = lowpass(noise(len(tt)), 0.12) * env(len(tt), decay_pow=4) + 0.5 * sine(80, tt) * env(len(tt), decay_pow=3)
    save("flipper_down", x, 0.4)

    tt = t(0.16)
    x = square(660 + 400 * np.exp(-tt * 40), tt) * env(len(tt), decay_pow=2.5) * 0.6
    x[: int(SR * 0.006)] += noise(int(SR * 0.006))
    save("bumper", x, 0.6)

    tt = t(0.08)
    x = lowpass(noise(len(tt)), 0.5) * env(len(tt), decay_pow=5) + 0.5 * square(440, tt) * env(len(tt), decay_pow=4)
    save("sling", x, 0.6)

    tt = t(0.06)
    x = sine(320 * (1 + 0.3 * np.exp(-tt * 60)), tt) * env(len(tt), decay_pow=3)
    save("post", x, 0.45)

    tt = t(0.3)
    sweep = lowpass(noise(len(tt)), 0.05 + 0.4 * (tt / tt[-1]))
    x = sweep * np.sin(np.pi * tt / tt[-1]) ** 0.5
    save("launch", x, 0.6)

    tt = t(0.07)
    x = square(1046, tt) * env(len(tt), decay_pow=2)
    save("target", x, 0.45)

    notes = [523, 659, 784, 1046, 1318]
    x = np.concatenate([square(f, t(0.07)) * env(int(SR * 0.07), decay_pow=1.2) for f in notes])
    save("bank_complete", x, 0.5)

    tt = t(0.5)
    x = square(440 * np.exp(-tt * 2.8), tt) * env(len(tt), decay_pow=1.0)
    save("drain", x, 0.5)

    tt = t(0.45)
    x = saw(110, tt) * (0.6 + 0.4 * square(12, tt)) * env(len(tt), decay_pow=0.8)
    save("tilt", x, 0.55)

    tt = t(0.1)
    x = sine(55, tt) * env(len(tt), decay_pow=2) + 0.4 * lowpass(noise(len(tt)), 0.08) * env(len(tt), decay_pow=3)
    save("nudge", x, 0.7)

    notes = [523, 392, 330, 262]
    x = np.concatenate([square(f, t(0.12)) * env(int(SR * 0.12), decay_pow=1.0) for f in notes])
    save("game_over", x, 0.5)

    print("Sonidos generados en", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
