-- Drive the actual rendered buttons, including pooled frames reused by details.
-- Catalog-wide checks call the button handlers directly; targeted checks below
-- additionally dispatch screen coordinates and respect scroll-frame clipping.
local A, f = TestAddon, TestAddon.window
local function copy(value)
    if type(value)~="table" then return value end
    local result={}; for k,v in pairs(value) do result[k]=copy(v) end; return result
end
local function restore(target, saved)
    for k in pairs(target) do target[k]=nil end
    for k,v in pairs(saved) do target[k]=copy(v) end
end
local saved={db=copy(A.db),character=copy(A.characterDB),state=copy(A.state),history=copy(A.history),
    lastClass=A.lastClass,scroll=f.scroll:GetVerticalScroll(),visible=f:IsShown(),
    needsRefresh=A.needsRefresh,needsLayout=A.needsLayout,layoutElapsed=A.layoutElapsed}
local visited, records, counts = {}, {}, {actions=0,passive=0,pages=0,hovers=0,nativeTips=0,icons=0,pooled=0,fields=0}
local function size(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
local function fingerprint(block)
    local parts={block.title or "",block.body or "",block.meta or ""}
    for _,b in ipairs(block.blocks or {}) do parts[#parts+1]=fingerprint(b) end
    for _,column in ipairs(block.columns or {}) do for _,b in ipairs(column) do parts[#parts+1]=fingerprint(b) end end
    return table.concat(parts,"|")
end
local function key(action)
    if action.view then return "view:"..action.view..":"..(action.filter or "")..":"..(action.query or "") end
    if action.kind=="card" then return "card:"..fingerprint(action.card) end
    if action.kind=="item" then return "item:"..(action.item.id or action.item.itemId)..":"..(action.item.displayName or action.item.name) end
    if action.kind=="supplyFamily" then return "supplyFamily:"..action.family..":"..A:GetContext().level end
    if action.kind=="profession" then return "profession:"..action.family end
    return action.kind..":"..(action.id or "")..":"..(action.index or "")
end
local function hover(frame)
    if frame.scripts.OnEnter then
        frame.scripts.OnEnter(frame); counts.hovers=counts.hovers+1
        local block=frame.block or (frame.parent and frame.parent.block)
        if block and block.itemId and frame.kind~="EditBox" then
            assert(GameTooltip.hyperlink=="item:"..block.itemId and GameTooltip:NumLines()>0,"Item row/icon hover did not use the native item tooltip")
            counts.nativeTips=counts.nativeTips+1
        end
    end
    if frame.scripts.OnLeave then frame.scripts.OnLeave(frame) end
end
local function visible(value) return not not value end
local function validateBlocks(parent,blocks)
    for index,block in ipairs(blocks) do
        local frame=parent.blocks[index]
        assert(frame and frame:IsVisible() and frame.block==block,"Rendered block does not match current document")
        assert(frame:GetWidth()>0 and frame:GetHeight()>0)
        assert(visible(frame.count:IsShown())==visible(block.supply),"Stale bag count in reused row")
        assert(visible(frame.quantity:IsShown())==visible(block.supply and not block.groupSupply and not block.readOnlyTarget),"Stale Carry field in reused row")
        assert(visible(frame.choose:IsShown())==visible(block.supply and block.pickRank),"Stale Use button in reused row")
        assert(not frame.choose:IsShown(),"Automatic profession rank exposes a manual Use button")
        assert(visible(frame.stock:IsShown())==visible(block.supply and not block.pickRank),"Stale stock status in reused row")
        assert(visible(frame.icon:IsShown())==visible(not block.columns and block.itemId~=nil),"Stale item icon in reused row")
        assert(visible(frame.iconHit:IsShown())==visible(not block.columns and block.itemId~=nil),"Stale icon click target")
        assert(visible(frame.iconBorder:IsShown())==visible(not block.columns and block.itemId~=nil),"Stale decorative icon rim")
        assert(not frame.iconBorder:IsMouseEnabled(),"Decorative icon border absorbs item clicks")
        for _,edge in ipairs(frame.statusBorder) do
            assert(visible(edge:IsShown())==visible(block.supply),"Stale supply status border")
        end
        local painted=block.supply or (block.action and not block.columns)
        assert(not frame.rule:IsShown(),"Unexpected separator around reference text")
        if block.body and not block.supply and not block.columns then
            assert(frame.body:GetHeight()>=frame.body:GetStringHeight(),"Reference text retains a clipped supply-row height")
        end
        if frame.rowArt then
            local artWidth=0
            for _,part in ipairs(frame.rowArt) do
                assert(visible(part:IsShown())==visible(painted),"Stale custom row artwork in a reused guide block")
                if painted then
                    assert(part:GetHeight()==frame:GetHeight(),"Row artwork retains the previous pooled height")
                    artWidth=artWidth+part:GetWidth()
                end
            end
            if painted then assert(math.abs(artWidth-frame:GetWidth())<.001,"Row artwork does not cover the row width") end
        end
        assert(visible(frame.chevron:IsShown())==visible(block.action and not block.supply and not block.columns),"Stale detail chevron")
        assert(visible(frame.stockTrack:IsShown())==visible(block.supply and not block.groupSupply and not block.readOnlyTarget),"Stale stock bar")
        local filled=block.supply and block.target and block.target>0 and block.count and block.count>0 and not block.readOnlyTarget
        assert(visible(frame.stockFill:IsShown())==visible(filled),"Stale stock bar fill")
        if filled then assert(frame.stockFill:GetWidth()<=frame.stockTrack:GetWidth() and frame.stockFill:GetWidth()>0) end
        assert(visible(frame.title:IsShown())==not visible(block.columns),"Stale column heading")
        assert(frame.highlight==(block.action and "Interface\\QuestFrame\\UI-QuestTitleHighlight" or nil),"Reused row retained the wrong action highlight")
        for columnIndex,column in ipairs(frame.columns) do
            if block.columns and block.columns[columnIndex] then
                assert(column:IsVisible()); validateBlocks(column,block.columns[columnIndex])
            else assert(not column:IsShown(),"Stale column in reused row") end
        end
        if frame.quantity:IsShown() then assert(frame.quantity.targetKey==block.targetKey) end
        for fieldIndex,field in ipairs(frame.fields or {}) do
            local data=block.fields and block.fields[fieldIndex]
            assert(visible(field:IsShown())==visible(data),"Stale structured field in a reused guide row")
            if data then
                assert(field.label:GetText()==data.label and field.value:GetText()==data.value,"Structured item field shows stale text")
                assert(field:IsMouseEnabled()==(data.itemId~=nil),"Recipe tooltip field has incorrect mouse behavior")
                local fx,fy,fw,fh=field:GetRect(); local rx,ry,rw,rh=frame:GetRect()
                assert(fx>=rx and fy>=ry and fx+fw<=rx+rw+.01 and fy+fh<=ry+rh+.01,"Structured field escapes the item detail")
                counts.fields=counts.fields+1
            end
        end
        counts.pooled=counts.pooled+1
    end
    for index=#blocks+1,#parent.blocks do assert(not parent.blocks[index]:IsShown(),"Unused pooled row is still visible") end
end
local function validate()
    for index,card in ipairs(A.document.cards) do
        local frame=f.cards[index]; assert(frame:IsVisible())
        validateBlocks(frame.content,card.blocks)
        local firstSupply
        for i,block in ipairs(card.blocks) do if block.supply then firstSupply=i; break end end
        for _,header in ipairs(frame.headers or {}) do
            assert(visible(header:IsShown())==visible(card.supplyTable and firstSupply),"Stale supply table header")
            if header:IsShown() then
                local _,hy,_,hh=header:GetRect()
                local _,ry=frame.content.blocks[firstSupply]:GetRect()
                assert(hy+hh<=ry+.01,"Supply headers overlap the first item row")
                if firstSupply>1 then
                    local _,py,_,ph=frame.content.blocks[firstSupply-1]:GetRect()
                    assert(py+ph<=hy+.01,"Profession guidance appears below or overlaps supply column headers")
                end
            end
        end
    end
    for index=#A.document.cards+1,#f.cards do assert(not f.cards[index]:IsShown(),"Stale grouped supply card remains visible") end
    assert(f.sidebar:IsShown(),"Navigation sidebar disappeared in a detail or companion view")
    assert(visible(f.back:IsShown())==A:CanGoBack())
    assert(visible(f.search:IsShown())==visible(A.document.view=="petguide" and A.document.searchable))
    assert(visible(f.atLevel:IsShown())==visible(A.document.levelFilter))
    assert(not f.missing or not f.missing:IsShown(),"Removed Missing-only control is visible")
    assert(not f.stockPanel or not f.stockPanel:IsShown(),"Removed stock summary strip is visible")
end
local function noSources()
    assert(f.refs==nil and A.references==nil and A.ShowReferences==nil,"Removed Sources UI remains available")
    assert(A.Guide.References==nil and A.Companion.References==nil,"Removed Sources formatter remains callable")
end
local walkPages
local function visitAction(frame,depth,viaIcon)
    local action=frame.block.action
    local before,history=A.state,#A.history
    MOCK.Click(viaIcon and frame.iconHit or frame)
    counts.actions=counts.actions+1
    if viaIcon then counts.icons=counts.icons+1 end
    assert(#A.history==history+1 and A.history[#A.history]==before,"Row click failed to push navigation history")
    assert(A.document.isDetail or action.view,"Row did not open its detail view")
    validate()
    local id=key(action)
    if not visited[id] then
        visited[id]=true
        local kind=action.kind or "view"
        records[kind]=records[kind] or {}
        records[kind][id]=true
        noSources()
        assert(depth<10,"Navigation unexpectedly exceeded bounded graph traversal")
        walkPages(depth+1)
    end
    assert(f.back:IsShown()); MOCK.Click(f.back)
    assert(A.state==before and #A.history==history,"Back did not restore the exact prior navigation state")
    validate()
end
local function visitBlock(frame,depth)
    local block=frame.block
    hover(frame)
    if frame.iconHit:IsShown() then hover(frame.iconHit) end
    if frame.quantity:IsShown() then hover(frame.quantity) end
    for _,field in ipairs(frame.fields or {}) do if field:IsShown() then hover(field) end end
    if block.columns then
        for _,column in ipairs(frame.columns) do if column:IsShown() then
            for _,child in ipairs(column.blocks) do if child:IsShown() then visitBlock(child,depth) end end
        end end
    end
    assert(not frame.choose:IsShown(),"A reference rank unexpectedly permits manual selection")
    if block.action then
        visitAction(frame,depth,false)
        if frame.iconHit:IsShown() then visitAction(frame,depth,true) end
    else
        local before,history=A.state,#A.history
        MOCK.Click(frame)
        if frame.iconHit:IsShown() then MOCK.Click(frame.iconHit) end
        assert(A.state==before and #A.history==history,"Non-action row changed navigation")
        counts.passive=counts.passive+1
    end
end
walkPages=function(depth)
    assert(A.document.continuous and A.document.page==1 and A.document.pages==1,"Every view must be a complete scrollable list")
    assert(f.previous==nil and f.nextPage==nil and f.pageText==nil)
    validate(); counts.pages=counts.pages+1
    local cardCount=#A.document.cards
    for cardIndex=1,cardCount do
        local count=#A.document.cards[cardIndex].blocks
        for index=1,count do visitBlock(f.cards[cardIndex].content.blocks[index],depth) end
    end
end

f:Show(); A:RestoreWindow()
A:SetProfile("mode","preview")
-- Exact reported failure: the first pooled supply Button becomes the inert
-- stock row inside Elixir of Agility, then regains its highlight after Back.
A:SetProfile("characterClass","Hunter"); A:SetLevel(32)
MOCK.Click(f.tabs[1]); MOCK.Click(f.filters[4])
local function agilityRow()
    for _,card in ipairs(f.cards) do if card:IsShown() then
        for _,row in ipairs(card.content.blocks) do if row:IsShown() and row.block.itemId==8949 then return row end end
    end end
end
local reported=agilityRow()
assert(reported and reported.block.itemId==8949 and reported.highlight)
MOCK.Click(reported); assert(A.document.isDetail)
local detail=f.cards[1].content.blocks[1]
assert(detail.block.itemId==8949 and detail.block.supply and not detail.block.action and detail.highlight==nil)
validate()
MOCK.Click(f.back); assert(agilityRow()==reported and reported.block.action and reported.highlight)
MOCK.Click(reported.iconHit); assert(A.document.isDetail and f.cards[1].content.blocks[1].highlight==nil)
MOCK.Click(f.back)
-- Navigation closes an open class dropdown and commits focused targets.
reported.quantity:SetFocus(); reported.quantity:SetText("6")
local committedItem=reported.quantity.targetKey
MOCK.Click(f.class); assert(f.classMenu:IsShown())
MOCK.Click(f.tabs[2])
assert(not f.classMenu:IsShown(),"Class dropdown remains open after navigation")
assert(not reported.quantity:HasFocus() and A.characterDB.targets[committedItem]==6,"Navigation did not commit the focused Carry input")
noSources()

-- Real dropdown buttons, all supply categories, and unlock boundaries. Full
-- level-by-level planner parity lives in run.py; this checks rendered controls.
for _,class in ipairs(A.Planner.classes) do
    MOCK.Click(f.class); assert(f.classMenu:IsShown())
    local choice
    for _,child in ipairs(f.classMenu.children) do if child.label and child.label:GetText()==class then choice=child end end
    assert(choice); MOCK.Click(choice)
    assert(A:GetContext().characterClass==class and not f.classMenu:IsShown())
    for _,level in ipairs({1,9,10,32,60}) do
        A:SetLevel(level)
        MOCK.Click(f.tabs[1]); assert(A.state.view=="supplies")
        for filterIndex=1,#A.Supplies.filters do
            MOCK.Click(f.filters[filterIndex]); assert(A.state.filter==A.Supplies.filters[filterIndex])
            walkPages(0)
            assert((A.state.query or "")=="" and (A.state.stock or "All")=="All","Supplies retains a filter with no visible control")
        end
        MOCK.Click(f.tabs[2]); assert(A.state.view=="training"); walkPages(0)
    end
end

-- Discover intermediate item tiers without rendering all 540 profiles again.
-- Only open the extra class/level menus needed to click an as-yet unseen item.
local expectedItems,pendingItems={},{}
for _,class in ipairs(A.Planner.classes) do
    for level=1,60 do
        local context=A:GetContext()
        context.characterClass,context.level,context.petLevel=class,level,level
        for _,record in ipairs(A.Supplies.Build(context,{filter="All"})) do
            local id=key({kind="item",item=record.item})
            if not expectedItems[id] and not visited[id] then pendingItems[#pendingItems+1]={id=id,class=class,level=level} end
            expectedItems[id]=true
        end
    end
end
for _,entry in ipairs(pendingItems) do
    if not visited[entry.id] then
        A:SetProfile("characterClass",entry.class); A:SetLevel(entry.level)
        MOCK.Click(f.tabs[1]); MOCK.Click(f.filters[1]); walkPages(0)
    end
end
for id in pairs(expectedItems) do assert(visited[id],"A reachable supply item was never opened through its rendered row: "..id) end

A:SetProfile("characterClass","Hunter"); A:SetLevel(60)
for _,tab in ipairs(f.tabs) do assert(tab.view~="petguide","Pet Guide is not a top-level tab") end
MOCK.Click(f.tabs[2]); assert(f.filters[3].filter=="Pet Guide")
MOCK.Click(f.filters[3]); assert(A.state.view=="petguide")
local expected={Families=17,Abilities=21,Pets=559,Care=5}
for index,label in ipairs({"Families","Abilities","Pets","Care"}) do
    MOCK.Click(f.filters[index]); assert(A.document.total==expected[label])
    walkPages(0)
end
for kind,total in pairs({family=17,ability=21,rank=111,pet=559,guide=5}) do
    assert(size(records[kind])==total,kind.." UI coverage incomplete: "..size(records[kind]).." / "..total)
end
assert(counts.icons>0 and size(records.item)>50)
for _,family in ipairs({"cooking","bandage","dummy","antivenom"}) do
    assert(records.profession and records.profession["profession:"..family],"Profession guidance was never opened: "..family)
end

-- Screen-coordinate dispatch catches overlays that handler-only tests cannot.
MOCK.Click(f.back); assert(A.state.view=="training","Companion remains accessible from Pet Guide")
MOCK.Click(f.filters[3]); MOCK.Click(f.filters[3]); A:SetProfile("mode","live")
A:RestoreWindow(); A:Layout(); f.scroll:SetVerticalScroll(0)
local function clickRow(frame)
    local x,y,w,h=frame:GetRect()
    assert(MOCK.ClickAt(x+math.min(80,w/2),y+h/2)==frame,"Another control intercepted an on-screen row click")
end
local first=f.cards[1].content.blocks[1]
clickRow(first); assert(A.document.isDetail); MOCK.Click(f.back)
local last=f.cards[1].content.blocks[#A.document.cards[1].blocks]
local x,y,w,h=last:GetRect()
local sx,sy,sw,sh=f.scroll:GetRect()
assert(y+h/2>=sy+sh,"Expected last catalog row below the initial viewport")
assert(MOCK.HitTest(x+80,y+h/2)~=last,"Off-screen row received a clipped click")
f.scroll.scripts.OnMouseWheel(f.scroll,-10000)
assert(f.scroll:GetVerticalScroll()==f.scroll:GetVerticalScrollRange())
clickRow(last); assert(A.document.isDetail); MOCK.Click(f.back)
f.scroll.scripts.OnMouseWheel(f.scroll,10000); assert(f.scroll:GetVerticalScroll()==0)

-- Search empty states, literal metacharacters, filters and Back restoration.
f.search:SetFocus(); f.search:SetText("%["); f.search.scripts.OnTextChanged(f.search,true)
assert(A.document.total==0); walkPages(0)
f.search.scripts.OnEscapePressed(f.search); assert(not f.search:HasFocus())
MOCK.Click(f.clear); assert(A.document.total==559)
MOCK.Click(f.atLevel); assert(A.state.atLevel)
for _,block in ipairs(A.document.cards[1].blocks) do
    local pet=A.Data.PetGuide.pets[block.action.index]
    assert(pet.tameable and pet.maxLevel<=A:GetContext().level)
end
MOCK.Click(f.atLevel); assert(not A.state.atLevel and A.document.total==559)
noSources()

-- Restore settings so subsequent serialized-login checks see their original
-- fixture, not the ranks and previews exercised by this interaction sweep.
A:CommitInputs()
restore(A.db,saved.db); restore(A.characterDB,saved.character)
A.state,A.history,A.lastClass=copy(saved.state),copy(saved.history),saved.lastClass
A:RestoreWindow(); A:Refresh(); f.scroll:SetVerticalScroll(saved.scroll)
f:SetShown(saved.visible)
A.needsRefresh,A.needsLayout,A.layoutElapsed=saved.needsRefresh,saved.needsLayout,saved.layoutElapsed
print(string.format("PASS: Actual UI menu handlers: %d row/icon opens, %d passive-row clicks, %d pages, %d tooltip hovers, %d native item tooltip checks, and %d pooled-row checks and %d structured-field checks; removed Sources and manual Use controls remain absent. All 9 classes and %d reachable item recommendations; 17 families, 21 abilities, 111 ranks, 559 creatures, 5 care guides; coordinate row clicks and scroll clipping.",counts.actions,counts.passive,counts.pages,counts.hovers,counts.nativeTips,counts.pooled,counts.fields,size(expectedItems)))
