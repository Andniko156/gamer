local M={}
local weapons={"rivet","coil","flame","steam","disk","rail","pendulum","acid"}
local arenas={"dock","alley","express","bastion"}
local bosses={"boss_dock","boss_alley","boss_train","boss_bastion"}
local cues={
    ui={.23,.055}, latch={.58,.16}, gate={.46,.1}, shut={.47,.1},
    reel={.31,.055}, reel_stop={.5,.1}, level={.72,.24}, reward={.69,.22},
    evolution={.76,.22}, victory={.72,.3}, defeat={.65,.3},
    rivet={.36,.14}, coil={.43,.18}, flame={.43,.22}, steam={.45,.22},
    disk={.35,.18}, rail={.54,.25}, pendulum={.48,.25}, acid={.41,.23},
    hurt={.81,.24}, coupling={.44,.42},
    boss_warn={.78,.7,"area_warn"}, dash_warn={.63,.50}, area_warn={.64,.55}, vent_warn={.58,.85},
    impact={.44,.08}, boss_impact={.69,.07,"impact"}, vent_burst={.53,.55,"steam"},
    boss_dock={.78,1}, boss_alley={.78,1}, boss_train={.82,1}, boss_bastion={.81,1},
}
local ambients={night=.21,factory=.31,interior=.30,hangar=.19,dock=.23,alley=.22,express=.24,bastion=.23}
local url={}
for name in pairs(cues) do url[name]="/audio#"..name end
for name in pairs(ambients) do url[name]="/audio#"..name end

local function level(value)
    if type(value)~="number" or value~=value then return 100 end
    return math.max(0,math.min(100,math.floor(value+.5)))
end

function M.new(saved)
    if type(saved)~="table" then saved={} end
    return {clock=0,next={},loops={},focused=true,settings_dirty=true,settings={
        master=level(saved.master),effects=level(saved.effects),ambience=level(saved.ambience),
        muted=saved.muted==true,
    }}
end

function M.apply_settings(mix)
    local settings=mix.settings
    sound.set_group_gain("master",settings.muted and 0 or (settings.master/100)^2)
    sound.set_group_gain("effects",(settings.effects/100)^2)
    sound.set_group_gain("ambience",(settings.ambience/100)^2)
    mix.settings_dirty=false
end

function M.play(mix,name,pan,gain,speed)
    if not mix.focused or mix.settings.muted or mix.settings.master==0 or mix.settings.effects==0 then return end
    local def=cues[name]
    if mix.clock<(mix.next[name] or 0) then return end
    mix.next[name]=mix.clock+def[2]
    local volume=def[1]*(gain or 1)
    sound.play(url[def[3] or name],{gain=volume,pan=pan or 0,speed=speed or 1})
    if volume>=.52 then mix.duck_until=mix.clock+.55 end
end

function M.battle(mix,state,kind,value,x,y)
    if kind=="boss" then M.play(mix,bosses[state.arena]);return end
    if kind=="weapon" then
        M.play(mix,weapons[value],0,state.evolved[value] and 1.12 or 1,
            (state.evolved[value] and .90 or 1)+.055*math.sin(mix.clock*17))
        return
    end
    if not x then M.play(mix,kind);return end
    local dx,dy=x-state.x,y-state.y
    local distance=math.sqrt(dx*dx+dy*dy)
    if distance>=270 then return end
    local pan=math.max(-.70,math.min(.70,dx/220))
    local gain=1-.68*math.max(0,distance-80)/190
    M.play(mix,kind,pan,gain)
end

function M.update(mix,dt,mode,arena,launch_time)
    if mix.settings_dirty then M.apply_settings(mix) end
    mix.clock=mix.clock+dt
    local name
    if launch_time then name=launch_time>=3.8 and "interior" or launch_time>=.60 and "factory" or "night"
    elseif mode=="hangar" or mode=="intro" then name="hangar"
    elseif mode=="run" or mode=="pause" or mode=="build" or mode=="chest" or mode=="level" then name=arenas[arena] end
    local target=name and mix.focused and ambients[name] or 0
    if mode=="pause" or mode=="build" or mode=="chest" or mode=="level" then target=target*.38 end
    if mix.clock<(mix.duck_until or 0) then target=target*.44 end
    if target>0 and not mix.loops[name] then
        sound.set_gain(url[name],0)
        sound.play(url[name])
        mix.loops[name]=0
    end
    for active,gain in pairs(mix.loops) do
        local wanted=active==name and target or 0
        local delta=math.max(-dt*.75,math.min(dt*.56,wanted-gain))
        if wanted==0 and gain+delta<=.002 then
            sound.stop(url[active])
            mix.loops[active]=nil
        elseif math.abs(delta)>.0001 then
            mix.loops[active]=gain+delta
            sound.set_gain(url[active],gain+delta)
        end
    end
end

return M
