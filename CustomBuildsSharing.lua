-- Whispered data is reviewed before import; no received code is executed.
local _,A=...
local B=A.CustomBuilds
local prefix="HCB_BUILD1"
B.receiving={}; B.received={}; B.outgoing={}
local function now() return GetTime and GetTime() or 0 end
function B:Share(build,target)
    target=type(target)=="string" and target:match("^%s*(.-)%s*$") or ""
    if #target<2 or #target>100 or target:find("[%c%s|:]") then return nil,"Enter a player name, optionally Name-Realm." end
    local text,err=self:Export(build); if not text then return nil,err end
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return nil,"In-game sharing is unavailable on this client." end
    if #self.outgoing>0 then return nil,"A build is already being sent. Wait a moment." end
    self.serial=(self.serial or 0)+1
    local token=tostring(math.floor(now()*1000)).."-"..self.serial
    local count=math.ceil(#text/200)
    for i=1,count do self.outgoing[i]={target=target,text=token..":"..i..":"..count..":"..text:sub((i-1)*200+1,i*200)} end
    return true
end
function B:Receive(message,channel,sender)
    if channel~="WHISPER" or type(sender)~="string" or type(message)~="string" or #message>254 then return end
    local token,index,total,part=message:match("^(%d+%-%d+):(%d+):(%d+):(.*)$")
    index,total=tonumber(index),tonumber(total)
    if not token or #token>30 or not index or not total or total<1 or total>21 or index<1 or index>total then return end
    local key=sender..":"..token
    local pending=0
    for k,v in pairs(self.receiving) do if now()-v.at>30 then self.receiving[k]=nil else pending=pending+1 end end
    local record=self.receiving[key]
    if not record then
        if index~=1 or pending>=4 then return end
        record={at=now(),parts={},total=total,size=0}; self.receiving[key]=record
    end
    if record.total~=total or record.parts[index] then return end
    record.parts[index]=part; record.size=record.size+#part
    if record.size>self.maxText then self.receiving[key]=nil; return end
    for i=1,total do if not record.parts[i] then return end end
    self.receiving[key]=nil
    local text=table.concat(record.parts); local build=self:Decode(text)
    if not build then return end
    self.receiveSerial=(self.receiveSerial or 0)+1
    local id=self.receiveSerial; self.received[id]={text=text,sender=sender}
    self.received[id-20]=nil
    A:Print(sender.." shared |cff66ccff|Haddon:HardcoreBuddy:build:"..id.."|h["..build.name.."]|h|r. Click to review talents and stat weights.")
end
function B:OpenLink(link)
    local id=type(link)=="string" and tonumber(link:match("^addon:HardcoreBuddy:build:(%d+)$"))
    if not id then return end
    local record=self.received[id]
    if record then A.CustomBuildsUI:Review(record.text,record.sender)
    else A:Print("This build link expired. Ask the sender to share it again.") end
end
local events=CreateFrame("Frame"); B.shareEvents=events
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent",function(_,event,...)
    if event=="PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(prefix) end
    else local p,message,channel,sender=...; if p==prefix then B:Receive(message,channel,sender) end end
end)
events:SetScript("OnUpdate",function(_,elapsed)
    if #B.outgoing==0 then return end
    B.sendElapsed=(B.sendElapsed or 0)+elapsed; if B.sendElapsed<.15 then return end
    B.sendElapsed=0
    local packet=table.remove(B.outgoing,1)
    local ok=pcall(C_ChatInfo.SendAddonMessage,prefix,packet.text,"WHISPER",packet.target)
    if not ok then B.outgoing={}; A:Print("Could not send the build. Use Export to share its code.") end
end)
if SetItemRef and hooksecurefunc then hooksecurefunc("SetItemRef",function(link) B:OpenLink(link) end) end
