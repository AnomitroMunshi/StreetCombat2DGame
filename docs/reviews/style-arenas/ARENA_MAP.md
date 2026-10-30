# Arena asset map

Runtime layout: `assets/art/backgrounds/style_arenas_v1/layout.json`. All non-WB map IDs resolve independent `<id>_backdrop.png` and `<id>_cutouts.png`. Each new street additionally resolves `<id>_crowd.png` and the shared street_props_v1 intact/broken atlas.

| Home style/map | Setting | Floor damage |
|---|---|---|
| Boxing | Boxing gym | Rubber |
| Muay Thai | Thai timber training camp | Wood |
| Karate, selection, training | Autumn temple courtyard | Temple gray stone |
| Kung Fu | Chinese courtyard | Stone |
| Taekwondo | Korean dojang | Rubber |
| Kickboxing | Urban gym | Rubber |
| Bangla Maar | Existing Howrah/Victoria street | Existing WB stone |
| Capoeira | Brazilian roda courtyard | Stone |
| JKD | Hong Kong rooftop | Concrete |
| Shared street_market | Indian market road | Concrete |
| Shared street_neon | Hong Kong neon road | Concrete |
| Shared street_oldtown | Brazilian old-town street | Stone |

Each new match draws uniformly from the player's home and the three shared streets. A Bangla Maar home draw then chooses its existing Howrah/Victoria variant. Arena stays fixed across rounds; rematch draws again. Rival selection never chooses the arena. Practice uses Karate temple. Crowds are independent decorative rear layers, with two clusters per street; they are static painted sprites.

Floor contact remains560, collision bounds90..1190. Side cutout inner faces70/1210; feet566. Crowds stand on rear baseline538 and props568. Atlas/source prompts retained. The street prop atlas uses column split710 and rows0,365,700,1024; dojo prop rows are unequal as documented in layout.

Validation: editor imports/parses, stage selection/randomization/persistence/props suite, material decal suite, and rendered normal/damaged/full-overscan captures. Review scripts preserve deterministic home-map captures through match_arena_override.

Cleanup: obsolete tracked dojo_wood_v1 removed. Unused untracked original-checkout West Bengal v1/Victoria v1 and Colosseum sources were moved recoverably to D:/firstGame-retired-art-v1. Active West Bengal decals and other referenced v1 directories retained. AGENTS.md records the rule.

Final merged validation: all 41 headless suites passed in 2m44s, including all nine finisher-contact shards, difficulty, stage and material decals. Independent code review reported no actionable correctness findings. Render capture passed with zero missing layers.
