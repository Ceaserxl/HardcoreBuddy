"""Exercise native item/talent boundaries, comparisons, and tooltip lifecycle."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT

lua, addon = boot()
lua.globals().GEAR_RENDER = '--render' in sys.argv
lua.execute((ROOT / 'tests/gear_advisor.lua').read_text(encoding='utf-8'))

if '--render' in sys.argv:
    import re
    from PIL import Image, ImageDraw, ImageFont
    from render_layout import font, plain
    # Keep every row inside the illustrative frame as the native block grows.
    # WoW sizes the real tooltip; this only sizes our offline render artifact.
    measure = ImageDraw.Draw(Image.new('RGB', (1, 1)))
    panels = {}
    for n, tip in lua.globals().GEAR_PREVIEWS.items():
        rows = []
        for index in range(1, tip.NumLines(tip)+1):
            left = lua.globals()[f'{tip.name}TextLeft{index}']
            right = lua.globals()[f'{tip.name}TextRight{index}']
            text, value = plain(left.GetText(left)), plain(right.GetText(right))
            has_icon = '|T' in text
            text = re.sub(r'\|T.*?\|t\s*', '', text)
            face = font(11 if 'Estimated stat score' in text else 12)
            available = 344-(22 if has_icon else 0)
            if value:
                assert measure.textlength(text, font=face)+12+measure.textlength(value, font=face)<=available, 'Tooltip columns overlap'
            wrapped = []
            current = ''
            for word in text.split():
                trial = current+' '+word if current else word
                if current and measure.textlength(trial, font=face)>available:
                    wrapped.append(current); current=word
                else:
                    current=trial
            wrapped.append(current)
            for line, fragment in enumerate(wrapped):
                assert measure.textlength(fragment,font=face)<=available, 'Tooltip text exceeds frame'
                rows.append((fragment,value if line==0 else '',face,has_icon and line==0,
                             tuple(round(left.color[i]*255) for i in range(1,4)),
                             tuple(round(right.color[i]*255) for i in range(1,4))))
        panels[n]=rows
    panel_height = max(300, max(len(rows) for rows in panels.values())*18+28)
    columns=2 if len(panels)>3 else 3
    rows_count=(len(panels)+columns-1)//columns
    canvas = Image.new('RGB', (12+columns*388, 44+rows_count*(panel_height+18)), '#17191c')
    draw = ImageDraw.Draw(canvas)
    draw.text((18, 12), 'OFFLINE TOOLTIP LAYOUT | Example items | Game fonts approximated', font=font(12), fill='#b7b1a4')
    for n, rows in panels.items():
        x, y, width = 16 + ((n-1)%columns)*388, 42+((n-1)//columns)*(panel_height+18), 368
        draw.rounded_rectangle((x, y, x + width, y+panel_height), 5, fill='#101117', outline='#66615a', width=2)
        for index,(text,value,face,has_icon,left_color,right_color) in enumerate(rows):
            tx = x + 12
            row_y=y+12+index*18
            if has_icon:
                icon = Image.open(ROOT / 'Media/SurvivorShield.tga').convert('RGBA').resize((18, 18), Image.Resampling.LANCZOS)
                canvas.paste(icon, (tx, row_y), icon)
                tx += 22
            draw.text((tx,row_y),text,font=face,fill=left_color)
            rx = x + width - 12 - draw.textlength(value, font=face)
            draw.text((rx,row_y),value,font=face,fill=right_color)
    target = ROOT / '.release/gear-advisor-preview.png'
    target.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(target)
    print(f'PASS: Tooltip column layout checked; preview: {target}')
