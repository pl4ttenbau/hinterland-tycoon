Rail audio prototypes v1 — 2026-11-23

Original procedural synthesis, with no sampled recordings or external audio.
48 kHz, 16-bit PCM, mono WAV; intended for positional game audio.
These are first-pass sound-design assets, not historical locomotive recordings.

wagon_roll_30kmh_loop.wav
  Periodic 11.52 s rolling loop, reference speed 30 km/h.
  Four axles at longitudinal offsets 0, 1.2, 5.2, 6.4 m, based on GHE drawing.
  Assumed 12 m rail-joint interval. Track interval is artistic, unverified.
  Vary pitch with actual speed / 30 km/h, with smooth changes.
  Fade to silence at standstill; avoid pitch=0. At very low speed the isolated
  impact is preferable to slowing the full loop to an unnatural rumble.
  Multiple wagons should start at different phases to avoid synchronized hits.

wheel_joint_impact.wav
  Single 0.42 s impact for optional distance-triggered joints; do not loop.
  Alternative to rhythmic loop layer, not an extra duplicate at full volume.

diesel_idle_720rpm_loop.wav / diesel_work_1440rpm_loop.wav
  Periodic 12 s loops, generic six-cylinder four-stroke character.
  Use only for diesel locomotives, never freight wagons or steam locomotives.
  Crossfade with engine load/throttle; diesel RPM need not follow vehicle speed.

Integration: set loop mode on looping WAV imports in Godot; smooth gain and
pitch changes, spatial attenuation and conservative mixing. Respect existing
audio buses, pause/time scale behavior and train lifecycle. Avoid one full-gain
player per wagon on large consists. Godot pitch_scale also changes duration.

Generator: /usr/bin/python3 generate_audio.py (NumPy required).
audio_report.json records peak, RMS, boundary step and clipping checks.
Loop beds are cyclic noise and periodic synthesis, without silence or fades
baked into loop boundaries. Apply start/stop fades at runtime.
Technical checks do not replace a listening check in the actual game mix.
