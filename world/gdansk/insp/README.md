# Historical map references

Use the **1:50,000** scans first, as requested. The `1_25000` folder is reserved for later; no 1:25,000 scans have been added.

## Industry research

[Industry candidates for the 1960s world](industries_research.md) lists historical factories, rural businesses and railway workshops, with dates, sources, possible game cargoes, and earlier/later or off-map examples.

[Industry comparison and implementation plan](industry_implementation_plan.md) compares those candidates with the current game recipes and records missing cargoes and import needs. [First placement notes](industry_placement_notes.md) cover the **20 markers now placed**, including the refinery and four farms/four ranches. Milk/dairy remains reserved for future work.

## Available sheets

For city coverage, 1960s settlement character and four dated photo references, see [Gdańsk districts in our crop](gdansk_districts/README.md). Modern boundary intersections are retained separately from historical evidence.

| Position | Western strip: 18°30′–18°45′ E | Middle: 18°45′–19°00′ E | East: 19°00′–19°15′ E |
| --- | --- | --- | --- |
| North: 54°20′–54°30′ N | [N-34-50-C Gdańsk](1_50000/gdansk_N-34-50-C_edition_1974_print_1976.jpg) | [N-34-50-D Mikoszewo / Sobieszewo area](1_50000/mikoszewo_N-34-50-D_edition_1974_print_1975.jpg) | Not collected |
| Middle: 54°10′–54°20′ N | Not collected | [N-34-62-B Ostaszewo](1_50000/ostaszewo_N-34-62-B_edition_1970-1974.jpg) | [N-34-63-A Nowy Dwór Gdański](1_50000/nowy_dwor_gdanski_N-34-63-A_survey_1985-1989_print_1992.jpg) |
| South: 54°00′–54°10′ N | Not collected | [N-34-62-D Tczew](1_50000/tczew_N-34-62-D_content_1985_edition_1988.jpg) | [N-34-63-C Malbork](1_50000/malbork_N-34-63-C_content_1985-1989.jpg) |

- **Gdańsk:** second PRL edition **1974**, printed **1976**. Covers our Stogi, Przeróbka and Rudno/Długie Ogrody neighbourhood centres. The source-material diagram mixes earlier survey dates with 1974 updates; it is not a uniform 1968 snapshot. No railway overlay; decimal border labels added on 2026-11-08.
- **Mikoszewo:** second PRL edition **1974**, printed **1975**, source-material diagram **1962/74**. Covers Górki Zachodnie, Sobieszewo and Świbno along the southern coastal strip; most of the sheet is sea. Later catalogues may name this sheet Gdańsk-Sobieszewo. No railway overlay; decimal border labels added on 2026-11-08.
- **Ostaszewo:** heading says first PRL edition 1970–74; the source-material diagram lists 1963/74, 1962/74 and 1970. Modern catalogues may title the same sheet Suchy Dąb. The red annotation covers only a small coastal edge fragment; historical inland railway traces remain incomplete.
- **Nowy Dwór Gdański:** content 1985–89, publication 1992. This file has a partial red railway reading aid; unmarked sections are not evidence that no railway existed.
- **Tczew:** edition 1988, content 1985, explicitly printed in the heading.
- **Malbork:** content 1985–89; publication line says Warszawa 1991, printing mark says 1992.

The original four sheets form a contiguous block approximately **18°45′–19°15′ E, 54°00′–54°20′ N**. The two added city sheets cover the northwestern city/island portion, including all four added Gdańsk neighbourhood centres. Some western and northeastern edge strips of the game frame remain uncollected.

The original four files have **partial red railway highlights**. These were rendered programmatically over the original scans, with original labels and geometry retained. Standard-gauge and narrow-gauge routes are highlighted where confidently identifiable; unmarked sections may still contain former railways. Existing modern alignment data helped locate tracks; former Nowy Dwór–Nowy Staw sections were traced from the printed map. The overlays are approximate reading aids, not complete historical railway inventories or survey-quality digitization. No image-generation result was used in these files. The two city sheets have **decimal coordinate labels only**, with no railway highlights.

These are references from different dates, not one uniform historical survey. Later maps alone do not establish a road or railway existed in 1960.

**Decimal border labels (2026-11-08):** all **six sheets** now have **54 decimal-degree labels each** (**324 total**), one at every one-minute division along all four sides. Blue is longitude E; red is latitude N. These are decimal versions of the printed **1942 datum**, **not WGS84 GPS coordinates**. Added blank margin strips keep the annotations clear of original text; the map area and existing railway overlays retain their pixel scale. Each scan frame was fitted separately. The previously accepted Nowy Dwór / Stegna / Sztutowo sheet was unchanged during the remaining-five pass. Per-sheet placement, arithmetic, input checksums and backup ZIP paths are recorded in the `decimal_coordinate_labels_N-34-*.json` files in the [generation subfolder](1_50000/generation), linked from the manifest. The validation report is stored there too.

Individual source URLs, coverage bounds, dimensions and checksums are recorded in [1_50000/manifest.json](1_50000/manifest.json). The original maps use the 1942 coordinate system; no georeferencing or stitching has been performed here.
