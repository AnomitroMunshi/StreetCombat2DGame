"""Inspect generated PNGs; does not edit their artwork."""
from pathlib import Path
import json
from PIL import Image
import numpy as np

ROOT = Path(__file__).parent
# Actual visual row gaps differ from requested thirds, occasionally by column.
SPECS = {
    'boxing': ([0,390,775,1024], [0,400,775,1024], [770,740,780]),
    'muay_thai': ([0,370,725,1024], [0,385,730,1024], [740,720,750]),
    'kung_fu': ([0,368,733,1024], [0,440,744,1024], [650,600,680]),
    'taekwondo': ([0,360,705,1024], [0,360,705,1024], [760,760,770]),
    'kickboxing': ([0,345,677,1024], [0,380,690,1024], [740,740,740]),
    'capoeira': ([0,376,697,1024], [0,405,705,1024], [620,620,735]),
    'jeet_kune_do': ([0,350,660,1024], [0,350,655,1024], [730,720,720]),
}
exports = {}
for name, (left_rows, right_rows, splits) in SPECS.items():
    im = Image.open(ROOT / f'{name}_props.png')
    assert im.size == (1536,1024) and im.mode == 'RGBA', name
    alpha = np.asarray(im.getchannel('A'))
    clear = float((alpha == 0).mean())
    assert clear > .15 and alpha[0,0] < 2, f'{name}: missing alpha'
    cells = []
    for row, split in enumerate(splits):
        pair = []
        for state, x0, x1, rows in [('intact',0,split,left_rows), ('broken',split,1536,right_rows)]:
            y0,y1 = rows[row:row+2]
            ys,xs = np.where(alpha[y0:y1,x0:x1] >= 38)
            assert len(xs), (name,row,state)
            box = [int(xs.min()+x0),int(ys.min()+y0),int(xs.max()-xs.min()+1),int(ys.max()-ys.min()+1)]
            pair.append({'state':state,'source_rect_xywh':box,'source_baseline_y':box[1]+box[3]})
        cells.append(pair)
    exports[name] = {'file':f'{name}_props.png','size':[1536,1024], 'fully_clear_fraction':clear,
        'alpha_extrema':[int(alpha.min()),int(alpha.max())], 'sprites':cells,
        'placement':'Use one uniform scale per intact/broken pair; align each measured source baseline to the same world floor. Source rectangles supersede requested equal thirds.'}
    print(f'{name}: RGBA, {clear:.1%} clear, six sprite bounds recorded')
(ROOT/'exports.json').write_text(json.dumps(exports,indent=2)+'\n',encoding='utf-8')
