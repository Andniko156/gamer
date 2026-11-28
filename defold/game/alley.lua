local street_scale=1.30
local wall=156*street_scale
local M={height=288,road_edge=145*street_scale,wall=wall,house_height=218,gate_depth=wall+23}
local abs,floor,min,max=math.abs,math.floor,math.min,math.max
local sides={-1,1}
local phase={[-1]=-106,[1]=-22}
-- PNG dimensions and landmarks measured from the canonical left-facing module.
-- Landmark coordinates use the PNG's top-left origin at two pixels per unit.
local kinds={
    {id="workshop",width=558,height=436},
    {id="pump",width=555,height=436,grate_x=475,grate_y=409},
    {id="loading",width=561,height=436},
}
local facade_scale=.5
local gate_half_depth=4

function M.new(seed)
    return {seed=seed%31,sections={}}
end

function M.section(map,row)
    local cached=map.sections[row]
    if cached then return cached end
    local y=row*M.height
    local cycle=(row+map.seed)%12
    local section={y=y,houses={},decals={}}
    local function decal(id,x,dy,w,h,angle)
        section.decals[#section.decals+1]={id=id,x=x,y=y+dy,w=w,h=h,angle=angle}
    end
    for i,side in ipairs(sides) do
        local kind=kinds[(row+map.seed+i-1)%#kinds+1]
        local low=y+phase[side]
        local width,height=kind.width*facade_scale,kind.height*facade_scale
        local high=low+height
        local passage={south=high,north=low+M.height,wall=M.wall,gate_depth=M.gate_depth}
        passage.stop=passage.gate_depth-gate_half_depth
        local house={kind=kind.id,side=side,front=side*M.road_edge,base=low,w=width,h=height,passage=passage,
            lamp={x=side*(passage.wall+5),y=passage.south+6,variant=(row+map.seed+i)%2+1}}
        section.houses[i]=house
        if kind.grate_x then
            section.vent_x=house.front+side*(kind.width-kind.grate_x)*facade_scale
            section.vent_y=house.base+(kind.height-kind.grate_y)*facade_scale
            section.vent_phase=(row+i)%4
        end
    end
    local side=cycle%2==0 and 1 or -1
    decal("wet_patch",side*(84+cycle%3*7),53,57,31,side<0 and 180 or 0)
    decal("wet_crescent",-side*90,213,38,22,cycle%3*90)
    decal("stone_wear",side*25,121,46,34,cycle%2*90)
    if cycle%2==0 then decal("access_cover",-side*70,156,27,27,cycle*30) end
    map.sections[row]=section
    return section
end

function M.edge(map,y,radius,side)
    local row=floor((y-radius-phase[side])/M.height)
    local house=M.section(map,row).houses[side<0 and 1 or 2]
    local p=house.passage
    if y-radius>=p.south and y+radius<=p.north then return p.stop end
    return p.wall
end

function M.blocked(map,x,y,radius)
    local side=x<0 and -1 or 1
    return abs(x)+radius>M.edge(map,y,radius,side)
end

function M.nearby_floor(map,x,y,radius)
    local left,right=M.edge(map,y,radius,-1)-radius,M.edge(map,y,radius,1)-radius
    return max(-left,min(right,x)),y
end
function M.vent_at(map,x,y)
    local row=floor(y/M.height)
    local chosen,best
    for candidate=row-1,row+1 do
        local section=M.section(map,candidate)
        if section.vent_x then
            local distance=(x-section.vent_x)^2+(y-section.vent_y)^2
            if not best or distance<best then chosen,best=section,distance end
        end
    end
    return chosen
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
    local distance=math.sqrt((tx-x)^2+(ty-y)^2)
    if distance<2 then return tx,ty end
    local step=min(22,distance)/distance
    if not M.blocked(map,x+(tx-x)*step,y+(ty-y)*step,9) then return tx,ty end
    return 0,y
end

return M
