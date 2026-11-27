# Hinterland Tycoon — Licence

## Code: MIT

Copyright (c) 2025–2026 the Hinterland Tycoon contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of
the source code of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including without
limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom
the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

"Source code" means the GDScript, scene, resource and configuration files of
this project (for example under `game/`, `scenes/`, `tests/` and `tools/`),
except the folders listed under "Third-party components" below.

## Own assets: all rights reserved

The project's own models, textures, maps, sounds and other media (for example
under `assets/` and `world/`) are Copyright (c) 2025–2026 the Hinterland Tycoon
contributors, all rights reserved, unless a file or this licence names another
source. They are not covered by the MIT licence above.

## Third-party components

### Editor and game addons

Each folder under `addons/` keeps the licence that ships with it (a `LICENSE`,
`LICENSE.txt` or `LICENSE.md` in the folder, or the licence named by its
author). This file does not relicense them.

### Sounds

Vehicle sounds keep a provenance file next to them with the source, author,
licence and any processing.

| File | Source | Author | Licence |
|---|---|---|---|
| `assets/sounds/vehicles/horns/wws_p8_steam_whistle.ogg` | [WWS SteamWhistle.ogg](https://commons.wikimedia.org/wiki/File:WWS_SteamWhistle.ogg) — whistle of Prussian P 8 38 2267, Bochum railway museum | Work With Sounds / Konrad Gutkowski, Julian Blaschke | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `assets/sounds/vehicles/horns/db628_makrofon.ogg` | [Makrofon DB Baureihe 628.ogg](https://commons.wikimedia.org/wiki/File:Makrofon_DB_Baureihe_628.ogg) — horn of a DB class 628 railcar | MdE (German Wikipedia) | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |
| `assets/sounds/vehicles/rail/brockenbahn_wagon_filtered_loop.wav` | [Brockenbahn.wav](https://freesound.org/people/viertelnachvier/sounds/267219/) (excerpt, filtered) | viertelnachvier | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |

Both horn files are unchanged copies of the originals; the game plays only part
of the Makrofon recording (the outside take). Under CC BY-SA 3.0 the Makrofon
file, and any edited version of it, stays under CC BY-SA 3.0; this does not
extend to the rest of the game.

Not yet cleared for distribution: `v100_diesel_loop.wav` and
`harz_99_7245_steam_first2s_loop.wav` in `assets/sounds/vehicles/rail/` come
from user-supplied video recordings whose reuse licence has not been
established (see `INTEGRATION.txt` there). Replace or clear them before
publishing a build.

The car horn is synthesized in code (`VehicleHorn`) and has no outside source.
