local run=require "game.run"
local audio=require "game.audio"

local state=run.new(1,1729,1,3)
state.enemies={}
local events={}
state.on_sound=function(_,kind,id)
    events[#events+1]={kind,id}
end
state.loot={{kind="xp",xp=1,x=state.x,y=state.y}}
run.step(state,1/60,0,0)
assert(state.xp==1 and #events==0,"picking up experience must be silent")

state.hazards={{kind="shock",x=state.x,y=state.y,radius=15,at=state.time,damage=1,duration=.3}}
run.step(state,1/60,0,0)
assert(#events==2 and events[1][1]=="impact" and events[2][1]=="hurt")
run.step(state,1/60,0,0)
assert(#events==2,"an active hazard must emit one impact")

local plays,gains,stops,groups={},{},{},{}
sound={
    play=function(url,options) plays[#plays+1]={url,options} end,
    set_gain=function(url,gain) gains[url]=gain end,
    stop=function(url) stops[url]=true end,
    set_group_gain=function(group,gain) groups[group]=gain end,
}
local mix=audio.new()
audio.update(mix,.4,"launch_wait",1,0)
assert(plays[1][1]=="/audio#night" and gains["/audio#night"]>0)
audio.update(mix,.1,"launch_movie",1,.7)
assert(plays[2][1]=="/audio#factory" and gains["/audio#night"]>0)
audio.update(mix,.4,"launch_movie",1,1.1)
assert(stops["/audio#night"])
audio.battle(mix,state,"weapon",5)
audio.battle(mix,state,"weapon",5)
assert(#plays==3 and plays[3][1]=="/audio#disk")
audio.battle(mix,state,"boss_warn",nil,state.x+300,state.y)
assert(#plays==3)
audio.battle(mix,state,"boss_warn",nil,state.x+60,state.y)
assert(plays[4][1]=="/audio#area_warn" and plays[4][2].pan>0)
mix.focused=false
audio.update(mix,1,"launch_movie",1,1.1)
assert(stops["/audio#factory"])
assert(groups.master==1 and groups.effects==1 and groups.ambience==1)
local saved={master=70,effects=50,ambience=0,muted=true}
local restored=audio.new(saved)
audio.update(restored,.1,"launch_wait",1,0)
assert(groups.master==0 and groups.effects==.25 and groups.ambience==0)
audio.play(restored,"ui")
assert(#plays==5,"muted sound effects must not enqueue playback")
restored.settings.muted=false
audio.apply_settings(restored)
assert(math.abs(groups.master-.49)<1e-9 and saved.muted)
local malformed=audio.new({master=-1,effects=999,ambience="bad"})
assert(malformed.settings.master==0 and malformed.settings.effects==100 and malformed.settings.ambience==100)
print("Audio: silent XP, one hazard onset, ambience crossfade, spatial warning, disk rate limit focus, saved levels and mute passed")
