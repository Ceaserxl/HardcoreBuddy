"""Reproduce Classic Era scalar bounds and contain model API failures."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
A.MapAdvisor:OpenNPCs({records={{id=12477}}})
local f=A.MapAdvisor.viewer
local scalar=f.actor.GetMaxBoundingBox
f.actor.bottom={x=-3.964900,y=-2.374035,z=-1.037348}
f.actor.top={x=3.251843,y=4.190925,z=3.883636}
local function loaded()
    f.model.modelFileID=123544
    f.model.scripts.OnModelLoaded(f.model)
end
local function advance(frames)
    for i=1,frames do
        f.model.modelFileID=123544
        f.model.scripts.OnUpdate(f.model,0.013)
    end
end
loaded()
assert(f.modelState=="loaded" and f.actor.shown and not f.waiting)
assert(math.abs(f.bounds.x-(-3.964900+3.251843)/2)<0.000001)
assert(math.abs(f.bounds.y-(-2.374035+4.190925)/2)<0.000001)
assert(math.abs(f.bounds.z-(-1.037348+3.883636)/2)<0.000001)
local radius=f.bounds.radius
advance(730)
assert(f.modelState=="loaded" and f.attempts==1 and not f.retry:IsShown())

-- Preserve compatibility with clients exposing the documented vector shape.
f.actor.GetMaxBoundingBox=function(self) return self.bottom,self.top end
f:RequestModel(true); loaded()
assert(f.modelState=="loaded" and f.bounds.radius==radius)

for _,bad in ipairs({
    function() return nil end,
    function() return 1,2 end,
    function() return {x=0,y=0,z=0},2 end,
    function() return 0,0,0,0,0,0 end,
    function() return 4,4,4,1,1,1 end,
    function() return 0,0,0,math.huge,1,1 end,
    function() return 0,0,0,0/0,1,1 end,
    function() error("Uncached bounding box") end,
}) do
    local calls=0
    f.actor.GetMaxBoundingBox=function() calls=calls+1; return bad() end
    f:RequestModel(true); loaded(); advance(730)
    assert(f.modelState=="failed" and f.attempts==3 and f.retry:IsShown())
    assert(not f.waiting and not f.actor.shown and not f.bounds)
    assert(calls<100,"Bounds polling is throttled")
    local stopped=calls; advance(730)
    assert(calls==stopped,"A failed load does not keep polling")
end
assert(f.modelError:find("Uncached bounding box",1,true))
f.actor.GetMaxBoundingBox=scalar
MOCK.Click(f.retry); loaded()
assert(f.modelState=="loaded" and not f.modelError and f.attempts==1,"Manual retry recovers")

local position=f.scene.SetCameraPosition; local calls=0
f.scene.SetCameraPosition=function() calls=calls+1; error("Camera API unavailable") end
f:RequestModel(true); loaded(); advance(730)
assert(calls==1 and f.modelState=="failed" and not f.settle and not f.waiting)
assert(f.modelError:find("Camera API unavailable",1,true) and f.retry:IsShown())
f.scene.SetCameraPosition=position; MOCK.Click(f.retry); loaded()
assert(f.modelState=="loaded")
print("PASS: Exact reported Classic bounds, vector compatibility, 730-frame regression, invalid/uncached bounds, bounded retries, camera failure and recovery.")
''')
