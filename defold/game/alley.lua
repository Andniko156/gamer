local M = {height=240}
local abs, floor, min, max = math.abs, math.floor, math.min, math.max
local centers = {0,-24,-48,-20,22,44,28,-6}
local props = {
    clockmaker_bench={96,94,39,13}, parts_cabinet={64,88,22,10}, gear_shop_sign={64,65},
    water_pump={68,68,23,10}, pressure_cabinet={62,84,24,10}, flush_drain={62,34},
    gas_lamp={60,108,7,5}, tool_handcart={80,66,25,11}, iron_railing={92,46,37,5},
    street_arch={142,131}, service_stairs={88,81}, brick_window={92,100},
    workshop_awning={104,48}, service_door={47,74}, wall_lantern={26,35},
    downspout={20,83}, roof_vents={55,46}, crate_stack={58,47,19,10},
}

function M.new(seed)
    return {seed=seed%31, sections={}}
end

local function solid(section,x,y,w,h)
    section.solids[#section.solids+1]={x=x,y=y,w=w,h=h}
end

local function place(section,id,x,y,layer)
    local p=props[id]
    section.props[#section.props+1]={id=id,x=x,y=y+p[2]*.5-3,w=p[1],h=p[2],layer=layer or "arena",foot=y,shadow=p[3]}
    if p[3] then solid(section,x,y,p[3],p[4]) end
end

local function decal(section,id,x,y,w,h,angle)
    section.decals[#section.decals+1]={id=id,x=x,y=y,w=w,h=h,angle=angle}
end

local function light(section,x,y,w,h)
    section.lights[#section.lights+1]={x=x,y=y,w=w,h=h}
end

local function decorate(section,row,cycle)
    local y,center=section.y,section.center
    local side=section.side
    local edge=side>0 and section.right or section.left
    local opposite=side>0 and section.left or section.right
    local shift=(cycle%4-1)*11
    decal(section,"wet_patch",center-side*(47+shift),y+46,59,31,cycle%2*180)
    decal(section,"wet_crescent",center+side*56,y+174+shift,37,22,cycle%3*90)
    decal(section,"stone_wear",center+shift,y+112,48,36,cycle%2*90)
    decal(section,"street_grit",opposite+side*31,y+91+shift,19,13)
    decal(section,"curb_drain",edge-side*14,y+88,8,36)
    decal(section,"curb_drain",opposite+side*14,y+185,8,36)
    if cycle%3==0 then decal(section,"access_cover",center+12,y+201,29,29,cycle*30) end
    if cycle%4==0 or cycle%4==2 then
        place(section,"service_door",opposite-side*18,y+28+shift,"fixtures")
        place(section,"wall_lantern",opposite+side*2,y+71+shift,"fixtures")
        light(section,opposite+side*16,y+78+shift,102,93)
    end
    if row%3~=1 then place(section,"downspout",edge+side*8,y+143,"fixtures") end
    if row%2==0 then place(section,"roof_vents",opposite-side*77,y+151,"fixtures") end
end

function M.section(map,row)
    local cached=map.sections[row]
    if cached then return cached end
    local cycle=(row+map.seed)%12
    local center=centers[row%#centers+1]
    local y=row*M.height
    local wide=cycle%4==3
    local side=floor((row+map.seed)/3)%2==0 and -1 or 1
    local half=cycle%3==0 and 184 or 173
    local l,r=center-half,center+half
    if wide then
        if side==1 then r=r+125 else l=l-125 end
    end
    local section={left=l,right=r,center=center,y=y,props={},solids={},decals={},lights={},wide=wide,side=side}
    map.sections[row]=section
    if wide then
        local island=center+side*(half-24)
        solid(section,island,y+120,25,47)
        section.island=island
        local arch=island+side*72
        place(section,"street_arch",arch,y+195,"fixtures")
        solid(section,arch-48,y+195,11,9)
        solid(section,arch+48,y+195,11,9)
        place(section,"service_stairs",side==1 and l+38 or r-38,y+177,"inlays")
        place(section,"wall_lantern",arch+side*49,y+236,"fixtures")
        light(section,arch+side*30,y+207,122,110)
    elseif cycle%3==0 then
        local x=side==1 and r-39 or l+39
        local shift=(cycle%4-1)*8
        place(section,"clockmaker_bench",x,y+53+shift)
        place(section,"parts_cabinet",x,y+117+shift)
        place(section,"gear_shop_sign",x-side*21,y+136+shift,"fixtures")
        place(section,"workshop_awning",x+side*11,y+171+shift,"alley_overhang")
        place(section,"wall_lantern",x-side*22,y+139+shift,"fixtures")
        light(section,x-side*14,y+110+shift,130,114)
        section.inlay={x=x,y=y+93,w=100,h=125,kind="workshop"}
    elseif cycle%3==1 then
        local x=side==1 and r-33 or l+33
        place(section,"water_pump",x,y+48)
        place(section,"pressure_cabinet",x,y+103)
        place(section,"flush_drain",x-side*30,y+146,"inlays")
        section.vent_x,section.vent_y=x-side*30,y+151
        section.inlay={x=x-side*8,y=y+102,w=108,h=136,kind="pump"}
        place(section,"wall_lantern",x+side*14,y+156,"fixtures")
        light(section,x-side*6,y+113,96,102)
    else
        local x=side==1 and r-32 or l+32
        place(section,"gas_lamp",x,y+141,"fixtures")
        place(section,"tool_handcart",x-side*9,y+77)
        place(section,"iron_railing",x,y+43)
        place(section,"crate_stack",x+side*8,y+111)
        light(section,x-side*11,y+179,153,148)
    end
    decorate(section,row,cycle)
    return section
end

function M.blocked(map,x,y,radius)
    local first,last=floor((y-radius)/M.height),floor((y+radius)/M.height)
    for row=first,last do
        local s=M.section(map,row)
        if x-radius<s.left or x+radius>s.right then return true end
        for _,p in ipairs(s.solids) do
            local dx,dy=max(0,abs(x-p.x)-p.w),max(0,abs(y-p.y)-p.h)
            if dx*dx+dy*dy<radius*radius then return true end
        end
    end
    return false
end

function M.nearby_floor(map,x,y,radius)
    local row=floor(y/M.height)
    local s=M.section(map,row)
    local l,r=s.left,s.right
    for _,other in ipairs({floor((y-radius)/M.height),floor((y+radius)/M.height)}) do
        if other~=row then
            local neighbor=M.section(map,other)
            l,r=max(l,neighbor.left),min(r,neighbor.right)
        end
    end
    x=max(l+radius,min(r-radius,x))
    if not M.blocked(map,x,y,radius) then return x,y end
    return max(l+radius,min(r-radius,s.center)),y
end

function M.move(map,x,y,dx,dy,radius)
    local steps=max(1,math.ceil(max(abs(dx),abs(dy))/6))
    dx,dy=dx/steps,dy/steps
    for _=1,steps do
        local nx,ny=x+dx,y+dy
        if not M.blocked(map,nx,ny,radius) then
            x,y=nx,ny
        else
            if not M.blocked(map,nx,y,radius) then x=nx end
            if not M.blocked(map,x,ny,radius) then y=ny end
        end
    end
    return x,y
end

function M.route(map,x,y,tx,ty)
    local row,target=floor(y/M.height),floor(ty/M.height)
    local s=M.section(map,row)
    local delta=target-row
    local distance=math.sqrt((tx-x)^2+(ty-y)^2)
    if distance<2 then return tx,ty end
    local step=min(22,distance)/distance
    if not M.blocked(map,x+(tx-x)*step,y+(ty-y)*step,9) then return tx,ty end
    if abs(x-s.center)>14 then return s.center,y end
    if delta~=0 then
        local next_row=M.section(map,row+(delta>0 and 1 or -1))
        return next_row.center,delta>0 and s.y+M.height+16 or s.y-16
    end
    return s.center,ty
end

return M
