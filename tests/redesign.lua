-- Fixed-window skin regressions use real rectangles and mouse dispatch. Artwork
-- pixels are validated separately by render_layout.py against shipped assets.
local A,f=TestAddon,TestAddon.window
local function copy(value)
    if type(value)~="table" then return value end
    local out={}; for k,v in pairs(value) do out[k]=copy(v) end; return out
end
local saved={profile=copy(A.db.profile),window=copy(A.db.window),state=copy(A.state),history=copy(A.history),
    lastClass=A.lastClass,scroll=f.scroll:GetVerticalScroll(),needsLayout=A.needsLayout,needsRefresh=A.needsRefresh,
    textWidth=TEST_TEXT_WIDTH,measure=TEST_MEASURE,previewInitialized=A.db.previewInitialized,
    screenWidth=UIParent.width,screenHeight=UIParent.height}
local checks,layouts=0,0
local function check(value,message) checks=checks+1; assert(value,message) end
local function overlap(a,b)
    local ax,ay,aw,ah=a:GetRect(); local bx,by,bw,bh=b:GetRect()
    return ax<bx+bw and bx<ax+aw and ay<by+bh and by<ay+ah
end
local function inside(frame,parent)
    local x,y,w,h=frame:GetRect(); local px,py,pw,ph=parent:GetRect()
    return x>=px-.01 and y>=py-.01 and x+w<=px+pw+.01 and y+h<=py+ph+.01
end
local function hit(frame)
    local x,y,w,h=frame:GetRect()
    check(MOCK.HitTest(x+w/2,y+h/2)==frame,"Skinned control is covered at its clickable center")
end
local function inspect()
    local controls={f.mode,f.close,f.back,f.class,f.minus,f.plus,f.level,f.search,f.clear,f.atLevel}
    check(f.previous==nil and f.nextPage==nil and f.pageText==nil,"Paging controls remain")
    for _,button in ipairs(f.tabs) do controls[#controls+1]=button end
    for _,button in ipairs(f.filters) do controls[#controls+1]=button end
    local visible={}
    for _,control in ipairs(controls) do if control:IsVisible() then
        check(inside(control,f),"Responsive control extends outside the window")
        hit(control); visible[#visible+1]=control
    end end
    for i=1,#visible do for j=i+1,#visible do
        check(not overlap(visible[i],visible[j]),"Responsive controls overlap")
    end end
    check(f:GetWidth()==1040 and f:GetHeight()==660,"Fixed wide window geometry changed")
    check(not f:IsResizable() and f.resize==nil and not f.sizing,"Window still exposes resizing")
    check(f:GetScale()>0 and f:GetScale()<=1,"Window scaling enlarges or collapses the fixed layout")
    check(f:GetWidth()*f:GetScale()<=UIParent:GetWidth()-24+.01 and f:GetHeight()*f:GetScale()<=UIParent:GetHeight()-24+.01,"Fixed window does not fit the screen")
    check(f.refs==nil and A.references==nil and A.ShowReferences==nil,"Sources controls or handler survived removal")
    check(f.missing==nil and f.stockPanel==nil,"Removed Supplies controls or stock strip still exist")
    if A.document.view=="supplies" then
        check(not f.search:IsShown() and not f.searchLabel:IsShown() and not f.clear:IsShown(),"Supplies still shows search controls")
        check((A.state.query or "")=="" and (A.state.stock or "All")=="All","Supplies keeps a hidden query or stock filter")
    end
    check(f.scroll:GetHeight()>250,"Fixed chrome leaves insufficient scroll space")
    if A.document.view=="supplies" and not A.document.isDetail then
        local row=f.cards[1].content.blocks[1]
        check(row and row:IsVisible() and inside(row,f.scroll),"Supply view does not show one complete initial supply row")
    end
    check(not overlap(f.drag,f.mode) and not overlap(f.drag,f.close),"Decorated header intercepts planning or Close")
    local expected=true
    check(not not f.sidebar:IsShown()==expected,"Category sidebar disappeared from a view or detail")
    if f.sidebar:IsShown() then check(not overlap(f.sidebar,f.scroll),"Sidebar covers list content") end
    if f.back:IsShown() then
        local bx,by,bw,bh=f.back:GetRect(); local sx,sy=f.scroll:GetRect()
        check(bx>=sx-.01 and by+bh<=sy+.01,"Back is outside the right content section or overlaps its content")
        check(not overlap(f.back,f.sidebar),"Back overlaps the navigation sidebar")
    end
    local chrome=f.skinChrome
    check(chrome and inside(chrome.crest,f) and inside(chrome.banner,f),"Window artwork escaped the client area")
    check(chrome.headerBase and inside(chrome.headerBase,f) and inside(chrome.banner,chrome.headerBase),"Banner escaped its header backing")
    local uv=chrome.banner.texCoord
    local bx,by,bw,bh=chrome.banner:GetRect(); local hx,hy,hw,hh=chrome.headerBase:GetRect()
    check(math.abs(bx-hx)<.01 and math.abs(by-hy)<.01 and math.abs(bw-hw)<.01 and math.abs(bh-hh)<.01,"Banner does not fill the entire header backing")
    check(uv and #uv==4 and uv[1]>=0 and uv[2]<=1 and uv[3]>=0 and uv[4]<=1 and uv[2]>uv[1] and uv[4]>uv[3],"Header crop has invalid texture bounds")
    check(math.abs((2172/240)*(uv[2]-uv[1])/(uv[4]-uv[3])-bw/bh)<.0001,"Header cover crop distorts the artwork")
    local _,cy,cw,ch=chrome.crest:GetRect()
    check(math.abs(ch-math.min(92,bh))<.01 and math.abs(cw-ch)<.01,"Header emblem lost its larger square geometry")
    check(math.abs(cy+ch/2-(hy+hh/2))<.01,"Header emblem is not centered vertically")
    check(chrome.bannerBlend and inside(chrome.bannerBlend,chrome.banner),"Header edge blend escaped the artwork")
    local gradient=chrome.bannerBlend.gradient
    check(gradient and gradient.orientation=="HORIZONTAL" and gradient.first[4]==.65 and gradient.last[4]==0,"Header text backing lost its fade direction")
    for _,color in ipairs({gradient.first,gradient.last}) do for i=1,4 do
        check(color[i]>=0 and color[i]<=1,"Header edge blend has an invalid color channel")
    end end
    check(not overlap(f.mode,chrome.headerBase),"Planning button intrudes into the header")
    check(not overlap(f.mode,chrome.banner) and not overlap(f.mode,chrome.crest),"Planning button covers header artwork")
    check(not overlap(f.mode,f.title) and not overlap(f.mode,f.subtitle),"Planning button covers character/title text")
    check(f.mode.label:GetStringWidth()<=f.mode.label:GetWidth()+.01,"Planning button text is clipped")
    check(f.mode.label:GetStringHeight()<=f.mode.label:GetHeight()+.01,"Planning button text exceeds button height")
    check(f.mode.label:GetText()~="Preview","Planning control still uses the ambiguous Preview label")
    if f.levelGroup:IsVisible() then
        check(not f.levelLabel.wordWrap,"Level label must remain on one line")
        check(f.levelLabel:GetStringWidth()<=f.levelLabel:GetWidth(),"Level label is clipped")
        check(f.levelLabel:GetStringHeight()<=f.levelLabel:GetHeight(),"Level label clips vertically")
        check(not overlap(f.levelLabel,f.minus),"Level label overlaps decrement button")
        check(not overlap(f.minus,f.level) and not overlap(f.level,f.plus),"Level controls overlap")
        check(inside(f.plus,f.levelGroup),"Level controls escaped their measured group")
    end
    if f.searchLabel:IsVisible() then
        check(f.searchLabel.wordWrap==false,"Search label can split into multiple lines")
        check(f.searchLabel:GetStringWidth()<=f.searchLabel:GetWidth()+.01,"Search label is narrower than its rendered text")
        check(f.searchLabel:GetStringHeight()<=f.searchLabel:GetHeight()+.01,"Search label clips its font height")
        check(not overlap(f.searchLabel,f.search),"Search label overlaps the input")
    end
    layouts=layouts+1
end

local function clickPlanning()
    local before=A:GetContext().mode
    local x,y,w,h=f.mode:GetRect()
    check(MOCK.ClickAt(x+w/2,y+h/2)==f.mode,"Planning button click was intercepted")
    check(A:GetContext().mode~=before,"Planning button did not change character mode")
end
local screens={{1920,1080},{1366,768},{1040,700},{1024,768},{800,600},{640,480}}
A:SetProfile("characterClass","Hunter")
for _,widerFonts in ipairs({false,true}) do
    -- Game fonts can be wider/taller than the default approximation. Widen the
    -- same measurements consumed by runtime Layout instead of changing labels.
    if widerFonts then
        TEST_TEXT_WIDTH=function(text,size,path)
            return 1.20*(saved.textWidth and saved.textWidth(text,size,path) or #text*size*.53)
        end
        TEST_MEASURE=function(text,width,size,path,wrap)
            if saved.measure then return 1.10*saved.measure(text,width/1.20,size,path,wrap) end
            local lines=0
            for line in (text.."\n"):gmatch("(.-)\n") do
                lines=lines+(wrap==false and 1 or math.max(1,math.ceil(#line*size*.53*1.20/math.max(1,width))))
            end
            return lines*(size+2)*1.10
        end
    end
    for _,size in ipairs(screens) do
        UIParent.width,UIParent.height=size[1],size[2]
        A:RestoreWindow()
        for _,mode in ipairs({"live","preview"}) do
            A:SetProfile("mode",mode)
            for _,view in ipairs({"supplies","training","petguide"}) do
                A:Navigate(view); A:Refresh(); inspect()
                clickPlanning(); clickPlanning()
                local actionRow
                for _,card in ipairs(f.cards) do if card:IsShown() then
                    for _,candidate in ipairs(card.content.blocks) do
                        if candidate:IsShown() and candidate.block.action then actionRow=candidate; break end
                    end
                    if actionRow then break end
                end end
                check(actionRow~=nil,"Top-level view has no detail to inspect")
                MOCK.Click(actionRow); check(A.document.isDetail,"Detail route did not open")
                inspect()
                clickPlanning(); clickPlanning()
                local category=f.filters[1]
                hit(category); MOCK.Click(category)
                check(not A.document.isDetail and #A.history==0,"Sidebar navigation did not leave the detail and clear history")
            end
        end
    end
end
TEST_TEXT_WIDTH,TEST_MEASURE=saved.textWidth,saved.measure

-- The fixed geometry still preserves native BackdropTemplate handlers.
local before=f.backdropResizeCalls or 0
f:SetSize(1040,660)
check((f.backdropResizeCalls or 0)>before,"Native backdrop sizing handler was removed")

-- Three-piece native buttons must resize immediately, without a hover event.
local button=f.mode
local width,height=button:GetWidth(),button:GetHeight()
local wasActive=button.skinButton.active
button:SetSize(width+17,height+4)
local skin=button.skinButton
check(not skin.left:IsShown() and not skin.middle:IsShown() and not skin.right:IsShown(),"Legacy bevels must remain hidden")
check(skin.highlight:GetWidth()==button:GetWidth() and skin.highlight:GetHeight()==button:GetHeight(),"Flat button highlight follows resized bounds")
check(skin.active==wasActive,"Button resize changed its active state")
button:SetSize(width,height)

-- Every class remains reachable; adjacent dropdown buttons must not overlap.
UIParent.width,UIParent.height=1920,1080
A:RestoreWindow(); A:SetProfile("mode","preview"); A:Navigate("supplies"); A:Refresh()
MOCK.Click(f.class)
local classButtons={}
for _,child in ipairs(f.classMenu.children) do if child.kind=="Button" then classButtons[#classButtons+1]=child; hit(child) end end
check(#classButtons==9,"Class dropdown lost a class")
for i=1,#classButtons do for j=i+1,#classButtons do check(not overlap(classButtons[i],classButtons[j]),"Class dropdown rows overlap") end end
MOCK.Click(f.tabs[2])
check(not f.classMenu:IsShown(),"Navigation leaves class dropdown open")
check(f.refs==nil and A.references==nil and A.ShowReferences==nil,"Removed Sources flow remains available")

A.db.profile,A.db.window=copy(saved.profile),copy(saved.window)
A.db.previewInitialized=saved.previewInitialized
A.state,A.history,A.lastClass=copy(saved.state),copy(saved.history),saved.lastClass
UIParent.width,UIParent.height=saved.screenWidth,saved.screenHeight
A:RestoreWindow(); A:Refresh(); f.scroll:SetVerticalScroll(saved.scroll)
A.needsLayout,A.needsRefresh=saved.needsLayout,saved.needsRefresh
print(string.format("PASS: %d redesign assertions across %d fixed-window screen/mode/view combinations and two font metrics; fixed 1040x660 geometry, uniform screen fitting, planning/search text bounds and real clicks, complete supply rows, banner bounds, removed Sources, native backdrop hooks, immediate bevel resizing and non-overlapping class dropdown.",checks,layouts))
