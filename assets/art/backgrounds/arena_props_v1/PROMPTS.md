# Breakable props for the seven arenas without them

Each arena gets one transparent 1536×1024 sheet. Save each sheet as `assets/art/backgrounds/arena_props_v1/<arena>_props.png`, where `<arena>` is one of `boxing`, `muay_thai`, `kung_fu`, `taekwondo`, `kickboxing`, `capoeira` or `jeet_kune_do`.

## Sheet layout

The layout matches the existing `street_props_v1` sheet, so the game slices the new sheets the same way.

- **Rows:** three, one prop per row. The row boundaries are 0–341, 341–682 and 682–1024. Nothing may cross a row boundary.
- **Columns:** the intact object goes in the left half (x 0–768) and its broken version in the right half (x 768–1536).
- **Pairs:** each broken version keeps the same scale and floor baseline as its intact version.
- **Alpha:** real transparency, including the gaps inside objects. No ground plane, cast shadow, people, text or dividers.

In game, each prop is drawn about 55–75 px tall, standing in front of the back wall at the corners. Simple, bold silhouettes therefore read best.

## Prompts

Paste one prompt per sheet.

### Boxing gym
Warm brick wall, big windows and an evening city glow.

```
Transparent PNG 1536x1024 polished hand-painted 2D fighting game breakable prop sprite sheet for an old boxing gym with warm brick walls and evening window light. Three rows, each the intact object on the left half and its broken version on the right half, SAME scale and floor baseline within each pair. Row1: wooden corner stool with a dented metal water bucket and a folded towel on it -> stool snapped with a broken leg, bucket tipped over, towel fallen. Row2: wooden crate holding rolled hand wraps and an old pair of boxing gloves -> crate splintered open, wraps unrolled, gloves spilled. Row3: low wooden locker-room bench -> bench snapped into two sections with splinters. Side-on view, warm upper-left light, true alpha background including interior gaps, complete silhouettes with generous transparent padding, no ground planes or cast shadows, no people, no text. Row boundaries 0..341, 341..682, 682..1024; nothing crosses a row boundary; intact objects in x 0..768, broken in x 768..1536. No dividers.
```

### Muay Thai training camp
Wooden floor, a tropical Thai valley with a temple in the far distance.

```
Transparent PNG 1536x1024 polished hand-painted 2D fighting game breakable prop sprite sheet for an open-air Muay Thai training camp in tropical Thailand with a wooden floor and sunny afternoon light. Three rows, each the intact object on the left half and its broken version on the right half, SAME scale and floor baseline within each pair. Row1: large glazed brown clay water jar -> jar shattered into curved shards with a small water splash on the floor. Row2: woven rattan basket full of green coconuts -> basket crushed, coconuts rolled apart, one split open. Row3: low bamboo bench -> bamboo bench collapsed with split bamboo poles. Side-on view, warm upper-left sunlight, true alpha background including interior gaps, complete silhouettes with generous transparent padding, no ground planes or cast shadows, no people, no text, no religious objects. Row boundaries 0..341, 341..682, 682..1024; nothing crosses a row boundary; intact objects in x 0..768, broken in x 768..1536. No dividers.
```

### Kung Fu courtyard
Cream plaster wall, tiled roofs, red lanterns, bonsai, misty mountains.

```
Transparent PNG 1536x1024 polished hand-painted 2D fighting game breakable prop sprite sheet for a traditional Chinese kung fu courtyard with cream plaster walls, grey roof tiles and soft daylight. Three rows, each the intact object on the left half and its broken version on the right half, SAME scale and floor baseline within each pair. Row1: blue-and-white glazed ceramic planter with a small pine shrub -> planter shattered, soil spilled, shrub tipped over. Row2: bundle of bamboo training staffs standing in a low wooden stand -> stand broken and staffs snapped and scattered. Row3: low wooden tea table with a clay teapot and two cups -> table split in half, teapot and cups in shards. Side-on view, soft upper-left daylight, true alpha background including interior gaps, complete silhouettes with generous transparent padding, no ground planes or cast shadows, no people, no text, no religious objects. Row boundaries 0..341, 341..682, 682..1024; nothing crosses a row boundary; intact objects in x 0..768, broken in x 768..1536. No dividers.
```

### Taekwondo dojang
Clean beige walls, a blue mat floor, a wooden equipment rack.

```
Transparent PNG 1536x1024 polished hand-painted 2D fighting game breakable prop sprite sheet for a modern Korean taekwondo dojang with clean beige walls, blue floor mats and bright soft light. Three rows, each the intact object on the left half and its broken version on the right half, SAME scale and floor baseline within each pair. Row1: stack of pale pine board-breaking practice boards on a low wooden holder -> boards split cleanly in half along the grain, holder knocked over. Row2: small wooden shoe cubby shelf with a few pairs of white training shoes -> shelf cracked and leaning, shoes spilled. Row3: low wooden waiting bench -> bench snapped into two sections with splinters. Side-on view, bright soft upper-left light, true alpha background including interior gaps, complete silhouettes with generous transparent padding, no ground planes or cast shadows, no people, no text, no flags. Row boundaries 0..341, 341..682, 682..1024; nothing crosses a row boundary; intact objects in x 0..768, broken in x 768..1536. No dividers.
```

### Kickboxing gym
Dark rubber floor, brick wall, a skyline at sunset, heavy bags.

```
Transparent PNG 1536x1024 polished hand-painted 2D fighting game breakable prop sprite sheet for a gritty kickboxing gym with brick walls, black rubber floor and warm sunset window light. Three rows, each the intact object on the left half and its broken version on the right half, SAME scale and floor baseline within each pair. Row1: grey metal folding chair -> chair bent and collapsed flat. Row2: blue plastic water-cooler jug on a small metal stand -> jug cracked and tipped with a water splash, stand bent. Row3: stacked wooden crate holding shin guards and kick pads -> crate splintered, pads tumbled out. Side-on view, warm upper-left light, true alpha background including interior gaps, complete silhouettes with generous transparent padding, no ground planes or cast shadows, no people, no text, no logos. Row boundaries 0..341, 341..682, 682..1024; nothing crosses a row boundary; intact objects in x 0..768, broken in x 768..1536. No dividers.
```

### Capoeira roda
A sunny Brazilian square, warm plaster walls, palms.

```
Transparent PNG 1536x1024 polished hand-painted 2D fighting game breakable prop sprite sheet for a sunny Brazilian square where a capoeira roda is held, warm plaster walls, palm plants and golden afternoon light. Three rows, each the intact object on the left half and its broken version on the right half, SAME scale and floor baseline within each pair. Row1: terracotta planter with a leafy tropical plant -> planter shattered, soil spilled, plant tipped over. Row2: wooden fruit crate with mangoes and a pineapple -> crate splintered, fruit scattered, one mango squashed. Row3: rustic painted wooden bench in faded turquoise -> bench snapped into two sections with paint-chipped splinters. Side-on view, warm upper-left sunlight, true alpha background including interior gaps, complete silhouettes with generous transparent padding, no ground planes or cast shadows, no people, no text, no musical instruments. Row boundaries 0..341, 341..682, 682..1024; nothing crosses a row boundary; intact objects in x 0..768, broken in x 768..1536. No dividers.
```

### Jeet Kune Do: Hong Kong rooftop
Concrete roof, pipes, an AC unit, a wooden dummy, a sunset skyline.

```
Transparent PNG 1536x1024 polished hand-painted 2D fighting game breakable prop sprite sheet for a Hong Kong apartment rooftop at sunset with concrete floor, pipes and air-conditioner units. Three rows, each the intact object on the left half and its broken version on the right half, SAME scale and floor baseline within each pair. Row1: stack of three red plastic stools -> stools cracked and scattered, one split. Row2: two stacked wooden shipping pallets -> pallets splintered with broken slats. Row3: dented metal bucket and a green potted plant on a small wooden crate -> crate crushed, bucket rolled over, pot cracked with soil spilled. Side-on view, warm low sunset light from the upper left, true alpha background including interior gaps, complete silhouettes with generous transparent padding, no ground planes or cast shadows, no people, no text, no signs. Row boundaries 0..341, 341..682, 682..1024; nothing crosses a row boundary; intact objects in x 0..768, broken in x 768..1536. No dividers.
```

## What I will do with each sheet

- Measure the real row and column cuts and check the transparency.
- Add a layout entry for the arena: the sheet path, the measured row cuts and split, and where each prop stands, at the corners and clear of the fighting lane.
- Render the arena intact and broken, run the stage tests, and fix anything that doesn't line up.
