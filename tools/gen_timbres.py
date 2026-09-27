"""Generate source-informed attack/body wavetable pairs for four timbres.

Each 32-bit ROM word packs ``body[31:16]`` and ``attack[15:0]``. The HDL
crossfades the two spectra after note-on. No sampled audio is stored.
"""

from math import cos, exp, pi, sin, sqrt
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TABLE_SIZE = 1024


def drawbar_level(position):
    """Hammond drawbar steps are approximately 3 dB apart."""
    return 0.0 if position == 0 else 10.0 ** (3.0 * (position - 8) / 20.0)


def organ_coefficients():
    # Hammond SKX PRO manual: Harmonic Diapason 8' = 00 8877 760.
    # Its two non-integer/subharmonic drawbars are zero, so it fits one table.
    registration = (0, 0, 8, 8, 7, 7, 7, 6, 0)
    harmonic_for_drawbar = (None, None, 1, 2, 3, 4, 5, 6, 8)
    coeffs = [0.0] * 8
    for position, harmonic in zip(registration, harmonic_for_drawbar):
        if harmonic is not None:
            coeffs[harmonic - 1] = drawbar_level(position)
    return tuple(coeffs)


def piano_coefficients(midi=60, velocity=0.8):
    """Reduced C4 modal model from the public physics-piano implementation.

    A periodic table cannot retain note-dependent inharmonic modal frequencies.
    It does retain the hammer, strike, soundboard and partial-decay equations.
    Returned spectra represent t=0 and t=160 ms.
    """
    f0 = 440.0 * 2.0 ** ((midi - 69) / 12.0)
    key_pos = max(0.0, min(1.0, (midi - 21) / 87.0))
    effective_hardness = 0.15 + 0.85 * max(velocity, 0.05) ** 1.5
    contact_time = 0.0018 * (2.5 - 1.9 * effective_hardness)
    hammer_cutoff = 2.5 / contact_time
    hammer_rolloff = 2.0 - 0.8 * effective_hardness
    base_rolloff = 1.2 + 0.3 * key_pos + 1.2 * key_pos * key_pos
    strike_pos = 0.12

    b1, b2, string_length = 1.1, 2.7e-4, 0.62
    spatial = (pi / string_length) ** 2
    prompt_factor = (1.2 + 0.3 * key_pos) * (0.7 + 0.5 * effective_hardness)
    after_factor = 0.45
    after_amount = (0.18 + 0.07 * key_pos) * (1.3 - 0.4 * effective_hardness)

    attack, body = [], []
    for n in range(1, 12):
        frequency = f0 * n
        amplitude = 1.0 / (n ** base_rolloff)
        amplitude /= 1.0 + (frequency / hammer_cutoff) ** hammer_rolloff
        ft = frequency * contact_time
        denominator = 1.0 - 4.0 * ft * ft
        cosine_mod = 1.0 if abs(denominator) < 1e-6 else min(
            abs(cos(pi * ft) / denominator), 1.0
        )
        amplitude *= 0.7 + 0.3 * cosine_mod
        amplitude *= max(abs(sin(pi * n * strike_pos)), 0.03)

        soundboard = 1.0
        for centre, width, gain in ((90, 30, 0.15), (170, 35, 0.12), (260, 45, 0.10)):
            soundboard += gain * exp(-0.5 * ((frequency - centre) / width) ** 2)
        soundboard += 0.40 * exp(-0.5 * ((frequency - 1800) / 800) ** 2)
        amplitude *= soundboard

        alpha = 0.8 * b1 + 0.2 * b1 / sqrt(n) + b2 * n * n * spatial
        coupling = sqrt(soundboard)
        after_n = after_amount / coupling
        envelope = ((1.0 - after_n) * exp(-0.160 * alpha * prompt_factor * coupling)
                    + after_n * exp(-0.160 * alpha * after_factor))
        attack.append(amplitude)
        body.append(amplitude * envelope)
    return tuple(attack), tuple(body)


def waveform(coefficients):
    return [
        sum(a * sin((h + 1) * 2.0 * pi * i / TABLE_SIZE)
            for h, a in enumerate(coefficients))
        for i in range(TABLE_SIZE)
    ]


def make_pair(attack_coeffs, body_coeffs, peak):
    attack, body = waveform(attack_coeffs), waveform(body_coeffs)
    scale = peak / max(max(abs(x) for x in attack), max(abs(x) for x in body))
    quantize = lambda value: max(-32768, min(32767, round(value * scale)))
    return [quantize(x) for x in attack], [quantize(x) for x in body]


def main():
    piano_low_attack, piano_low_body = piano_coefficients(midi=48)
    piano_attack, piano_body = piano_coefficients()
    organ = organ_coefficients()
    timbres = (
        ("sine", (1.0,), (1.0,), 32767),
        ("organ", organ, organ, 28000),
        ("piano_low", piano_low_attack, piano_low_body, 30000),
        ("piano", piano_attack, piano_body, 30000),
    )

    words = []
    for name, attack_coeffs, body_coeffs, peak in timbres:
        attack, body = make_pair(attack_coeffs, body_coeffs, peak)
        words.extend(((b & 0xffff) << 16) | (a & 0xffff) for a, b in zip(attack, body))
        print(f"{name:7s}: " + ", ".join(f"{x:.4f}" for x in attack_coeffs))
    if len(words) != 4096:
        raise RuntimeError(f"expected 4096 words, got {len(words)}")
    output = ROOT / "rom" / "timbres4.hex"
    output.write_text("".join(f"{value:08x}\n" for value in words), encoding="ascii")
    print(f"wrote {output}: {len(words)} packed attack/body words")


if __name__ == "__main__":
    main()
