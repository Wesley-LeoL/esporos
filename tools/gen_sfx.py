"""Gera os efeitos sonoros provisórios do jogo (assets/audio/*.wav), por síntese simples.

Cada som é um arquivo próprio: para trocar, basta pôr outro .wav (ou .ogg) com o mesmo nome
em assets/audio/, ou mudar o caminho na tabela autoload/sfx_table.gd. Ver docs/SONS.md.

Uso: python3 tools/gen_sfx.py
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


def t(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, a=0.005, d=0.2, curve=4.0):
    """Ataque linear curto e queda exponencial."""
    x = np.arange(n) / SR
    att = np.clip(x / max(a, 1e-4), 0, 1)
    dec = np.exp(-curve * np.clip(x - a, 0, None) / max(d, 1e-4))
    return att * dec


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x, k):
    """Passa-baixa de 1 polo (k 0-1: menor = mais abafado)."""
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def highpass(x, k):
    return x - lowpass(x, k)


def sweep(f0, f1, dur, wave_="sin"):
    tt = t(dur)
    f = np.linspace(f0, f1, len(tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave_ == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    if wave_ == "sq":
        return np.sign(np.sin(ph))
    return np.sin(ph)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def pad(x, dur):
    n = int(SR * dur)
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])


def save(name, x, gain=0.9):
    x = np.asarray(x, dtype=float)
    peak = np.max(np.abs(x)) or 1.0
    x = np.clip(x / peak * gain, -1, 1)
    data = (x * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def thud(dur=0.18, f=90, k=0.08):
    n = noise(dur)
    return lowpass(n, k) * env(len(n), 0.002, dur * 0.35) * 3 + np.sin(2 * np.pi * f * t(dur)) * env(int(SR * dur), 0.002, dur * 0.3)


def groan(f0, f1, dur, rough=0.35):
    base = sweep(f0, f1, dur, "saw")
    vib = 1 + 0.15 * np.sin(2 * np.pi * 5.5 * t(dur))
    b = lowpass(base * vib, 0.12) + rough * lowpass(noise(dur), 0.05)
    shape = np.sin(np.pi * np.linspace(0, 1, len(b))) ** 0.7
    return b * shape


def main():
    os.makedirs(OUT, exist_ok=True)
    # ---- personagem
    save("passo", lowpass(noise(0.07), 0.25) * env(int(SR * 0.07), 0.002, 0.03), 0.5)
    save("golpe_ar", highpass(noise(0.16), 0.3) * np.sin(np.pi * np.linspace(0, 1, int(SR * 0.16))) ** 2, 0.5)
    save("golpe_acerto", mix(thud(0.16, 110, 0.12), lowpass(noise(0.08), 0.5) * env(int(SR * 0.08), 0.001, 0.02) * 0.6))
    save("empurrao", mix(thud(0.2, 70, 0.06), highpass(noise(0.12), 0.2) * env(int(SR * 0.12), 0.01, 0.05) * 0.4))
    save("dor", groan(320, 230, 0.32, 0.2) * env(int(SR * 0.32), 0.01, 0.25, 2.0), 0.7)
    save("queda", mix(thud(0.3, 60, 0.05), lowpass(noise(0.25), 0.2) * env(int(SR * 0.25), 0.002, 0.1) * 0.5))
    save("comer", np.concatenate([lowpass(noise(0.05), 0.4) * env(int(SR * 0.05), 0.002, 0.02) for _ in range(3)] +
                                 [np.zeros(int(SR * 0.04))]), 0.5)
    save("beber", mix(*[pad(np.zeros(int(SR * 0.12 * i)), 0) if False else
                        np.concatenate([np.zeros(int(SR * 0.12 * i)), sweep(500, 900, 0.07) * env(int(SR * 0.07), 0.005, 0.04)])
                        for i in range(3)]), 0.45)
    save("curativo", highpass(noise(0.45), 0.4) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t(0.45))) * env(int(SR * 0.45), 0.05, 0.4, 2.0), 0.4)
    # ---- armas
    shot = mix(lowpass(noise(0.35), 0.35) * env(int(SR * 0.35), 0.001, 0.08) * 1.5, sweep(160, 50, 0.2) * env(int(SR * 0.2), 0.001, 0.06))
    save("tiro_pistola", shot)
    save("tiro_espingarda", mix(lowpass(noise(0.55), 0.22) * env(int(SR * 0.55), 0.001, 0.16) * 1.8,
                                sweep(110, 35, 0.3) * env(int(SR * 0.3), 0.001, 0.1)))
    save("torre_tiro", mix(highpass(noise(0.18), 0.2) * env(int(SR * 0.18), 0.001, 0.04), sweep(900, 300, 0.08) * 0.3 * env(int(SR * 0.08), 0.001, 0.03)), 0.7)
    clk = lambda f: highpass(noise(0.02), 0.6) * env(int(SR * 0.02), 0.0005, 0.006) + np.sin(2 * np.pi * f * t(0.02)) * 0.3 * env(int(SR * 0.02), 0.0005, 0.006)
    save("recarregar", np.concatenate([clk(2500), np.zeros(int(SR * 0.18)), clk(1800), np.zeros(int(SR * 0.1)), clk(3000)]), 0.6)
    save("sem_municao", clk(3200), 0.5)
    # ---- infectados
    save("infectado_gemido", groan(140, 95, 1.1, 0.5), 0.55)
    save("infectado_ataque", groan(240, 160, 0.35, 0.6) * env(int(SR * 0.35), 0.02, 0.3, 1.5), 0.7)
    save("infectado_morre", mix(groan(180, 70, 0.7, 0.5), thud(0.25, 60, 0.05) * 0.6), 0.7)
    save("chamador_grito", mix(groan(700, 1100, 1.2, 0.3) * 0.8, highpass(noise(1.2), 0.3) * 0.25 * np.sin(np.pi * np.linspace(0, 1, int(SR * 1.2)))), 0.85)
    save("explosao_esporos", mix(lowpass(noise(0.8), 0.08) * env(int(SR * 0.8), 0.01, 0.4) * 2, highpass(noise(0.8), 0.5) * env(int(SR * 0.8), 0.05, 0.6) * 0.3))
    save("saqueador_grito", groan(260, 420, 0.5, 0.15), 0.6)
    # ---- casa, portas, janelas
    creak = lowpass(sweep(300, 520, 0.4, "saw"), 0.05) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t(0.4)))
    save("porta_abre", creak * np.sin(np.pi * np.linspace(0, 1, len(creak))), 0.5)
    save("porta_fecha", mix(thud(0.2, 95, 0.1), creak[:int(SR * 0.12)] * 0.3), 0.7)
    save("porta_golpe", thud(0.22, 85, 0.07), 0.8)
    save("porta_arrombada", mix(thud(0.4, 60, 0.06) * 1.3, highpass(noise(0.4), 0.2) * env(int(SR * 0.4), 0.002, 0.15) * 0.5))
    shards = [np.concatenate([np.zeros(int(SR * rng.uniform(0, 0.3))),
                              np.sin(2 * np.pi * rng.uniform(2500, 6000) * t(0.15)) * env(int(SR * 0.15), 0.0005, 0.05)])
              for _ in range(12)]
    glass = mix(*shards, highpass(noise(0.5), 0.5) * env(int(SR * 0.5), 0.001, 0.12))
    save("vidro_quebra", glass, 0.8)
    save("barricada_golpe", mix(thud(0.18, 100, 0.12), highpass(noise(0.08), 0.3) * env(int(SR * 0.08), 0.001, 0.03) * 0.5), 0.75)
    save("barricada_quebra", mix(thud(0.45, 70, 0.08), highpass(noise(0.45), 0.25) * env(int(SR * 0.45), 0.002, 0.2) * 0.7))
    save("construir", np.concatenate([mix(thud(0.09, 180, 0.3), highpass(noise(0.03), 0.5) * 0.4) for _ in range(3)] + [np.zeros(int(SR * 0.1))]), 0.6)
    save("escada", np.concatenate([lowpass(noise(0.06), 0.3) * env(int(SR * 0.06), 0.002, 0.03) for _ in range(4)]), 0.5)
    save("abrir_gaveta", mix(lowpass(sweep(200, 140, 0.18, "saw"), 0.1) * env(int(SR * 0.18), 0.01, 0.12), thud(0.1, 120, 0.2) * 0.4), 0.5)
    save("pegar_item", mix(sweep(600, 900, 0.06) * env(int(SR * 0.06), 0.002, 0.03), lowpass(noise(0.05), 0.3) * 0.3), 0.4)
    save("fechadura_tenta", np.concatenate([clk(4000) * 0.6, np.zeros(int(SR * 0.09)), clk(3500) * 0.6, np.zeros(int(SR * 0.12)), clk(4200) * 0.5]), 0.45)
    save("fechadura_abre", mix(clk(2200), np.concatenate([np.zeros(int(SR * 0.05)), thud(0.1, 160, 0.3) * 0.5])), 0.6)
    save("fabricar", np.concatenate([mix(thud(0.07, 220, 0.4), highpass(noise(0.03), 0.5) * 0.3) for _ in range(4)]), 0.55)
    # ---- interface
    save("ui_clique", np.sin(2 * np.pi * 1200 * t(0.03)) * env(int(SR * 0.03), 0.001, 0.01), 0.35)
    save("ui_alerta", mix(sweep(880, 880, 0.12) * env(int(SR * 0.12), 0.002, 0.08), np.concatenate([np.zeros(int(SR * 0.13)), sweep(660, 660, 0.12) * env(int(SR * 0.12), 0.002, 0.08)])), 0.4)
    # ---- ambiente e máquinas (contínuos: viram laço no jogo)
    rain = lowpass(noise(3.0), 0.35) * 0.6 + highpass(noise(3.0), 0.6) * 0.15
    for _ in range(140):
        i = rng.integers(0, len(rain) - 200)
        drop = highpass(rng.uniform(-1, 1, 120), 0.6) * env(120, 0.0005, 0.002) * 0.6
        rain[i:i + 120] += drop
    save("chuva", rain, 0.5)
    wind = lowpass(noise(4.0), 0.02) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.3 * t(4.0)))
    save("vento", wind, 0.5)
    save("trovao", lowpass(noise(2.5), 0.03) * env(int(SR * 2.5), 0.05, 1.2, 2.5) * (1 + 0.5 * np.sin(2 * np.pi * 3 * t(2.5))), 0.9)
    gen = lowpass(sweep(55, 55, 2.0, "saw"), 0.15) + 0.3 * lowpass(noise(2.0), 0.1) * (0.6 + 0.4 * np.sin(2 * np.pi * 25 * t(2.0)))
    save("gerador_loop", gen, 0.45)
    hum = np.sin(2 * np.pi * 120 * t(2.0)) * 0.5 + 0.3 * lowpass(noise(2.0), 0.4)
    save("purificador_loop", hum, 0.3)
    motor = lowpass(sweep(70, 70, 2.0, "saw"), 0.2) * (0.7 + 0.3 * np.sin(2 * np.pi * 18 * t(2.0)))
    save("motor_loop", motor, 0.45)
    save("sirene", sweep(500, 900, 0.8) * np.sin(np.pi * np.linspace(0, 1, int(SR * 0.8))) ** 0.5, 0.5)
    print("sons:", len([f for f in os.listdir(OUT) if f.endswith(".wav")]))


if __name__ == "__main__":
    main()
