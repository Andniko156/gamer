local M={width=312*1.30,height=288*1.40,gap=28,wall=22,end_depth=20,scenery_speed=21}
M.opening=76*M.width/272
M.period=M.height+M.gap
local abs,floor,min,max=math.abs,math.floor,math.min,math.max

-- Top-left coordinates within a car, shared by the prop sprites and footprints.
local cars={
    {deck="deck_wood",passenger=true,props={
        {"seat_left",22,56,37,40,{3,20,32,38}},
        {"seat_left",22,241,37,40,{3,20,32,38}},
        {"seat_right",M.width-59,56,37,40,{5,20,34,38}},
        {"seat_right",M.width-59,241,37,40,{5,20,34,38}},
    }},
    {deck="deck_steel",props={
        {"crate_stack",28,69,43,41,{3,19,39,40}},
        {"netted_crates",M.width-74,209,48,44,{2,21,43,42}},
    }},
    {deck="deck_steel",tank={23,51,72,81},steam={M.width-49,238},props={
        {"tank_pipework",27,60,55,60,{2,29,49,59}},
        {"steam_grate",M.width-65,227,32,22},
    }},
}

for _,car in ipairs(cars) do
    car.solids={}
    for _,p in ipairs(car.props) do
        local box=p[6]
        if box then
            car.solids[#car.solids+1]={
                p[2]+box[1]-M.width/2,p[2]+box[3]-M.width/2,
                M.height-p[3]-box[4],M.height-p[3]-box[2],
            }
        end
    end
end

function M.car(row)
    return cars[row%#cars+1]
end

local function half_opening(z,radius)
    if z-radius<M.end_depth or z+radius>M.height-M.end_depth then
        return M.opening/2
    end
    return M.width/2-M.wall
end

function M.blocked(x,y,radius)
    local row=floor(y/M.period)
    local z=y-row*M.period
    if abs(x)+radius>half_opening(z,radius) then return true end
    for _,solid in ipairs(M.car(row).solids) do
        local dx=max(0,solid[1]-x,x-solid[2])
        local dy=max(0,solid[3]-z,z-solid[4])
        if dx*dx+dy*dy<radius*radius then return true end
    end
    return false
end

-- Trace the center of a direct shot against the same slabs and furniture
-- footprints that bound the walkable deck. The coupling itself is open.
local function segment_entry(x,y,dx,dy,left,right,bottom,top)
    if dx==0 and (x<=left or x>=right) or dy==0 and (y<=bottom or y>=top) then
        return 1
    end
    local x0,x1,y0,y1=0,1,0,1
    if dx~=0 then
        x0,x1=(left-x)/dx,(right-x)/dx
        if x0>x1 then x0,x1=x1,x0 end
    end
    if dy~=0 then
        y0,y1=(bottom-y)/dy,(top-y)/dy
        if y0>y1 then y0,y1=y1,y0 end
    end
    local enter=max(0,x0,y0)
    return enter<min(1,x1,y1) and enter or 1
end

local function side_entry(x,y,dx,dy,half,bottom,top)
    return min(segment_entry(x,y,dx,dy,-math.huge,-half,bottom,top),
        segment_entry(x,y,dx,dy,half,math.huge,bottom,top))
end

function M.projectile_limit(x,y,dx,dy)
    local limit=1
    for row=floor(min(y,y+dy)/M.period),floor(max(y,y+dy)/M.period) do
        local bottom=row*M.period
        local front,back=bottom+M.end_depth,bottom+M.height-M.end_depth
        limit=min(limit,
            side_entry(x,y,dx,dy,M.opening/2,bottom,front),
            side_entry(x,y,dx,dy,M.width/2-M.wall,front,back),
            side_entry(x,y,dx,dy,M.opening/2,back,bottom+M.period))
        for _,solid in ipairs(M.car(row).solids) do
            limit=min(limit,segment_entry(x,y,dx,dy,solid[1],solid[2],
                bottom+solid[3],bottom+solid[4]))
        end
    end
    return limit
end

function M.floor_position(x,y,radius)
    local z=y%M.period
    local limit=half_opening(z,radius)-radius
    x=max(-limit,min(limit,x))
    return not M.blocked(x,y,radius) and x or 0,y
end

function M.move(x,y,dx,dy,radius)
    local steps=max(1,math.ceil(max(abs(dx),abs(dy))/6))
    dx,dy=dx/steps,dy/steps
    for _=1,steps do
        local nx,ny=x+dx,y+dy
        if not M.blocked(nx,ny,radius) then
            x,y=nx,ny
        else
            if not M.blocked(nx,y,radius) then x=nx end
            if not M.blocked(x,ny,radius) then y=ny end
        end
    end
    return x,y
end

function M.route(x,y,tx,ty,radius)
    local dx,dy=tx-x,ty-y
    local length=math.sqrt(dx*dx+dy*dy)
    local facing_gap=floor(y/M.period)~=floor(ty/M.period)
    local forward=min(28,length)/max(.001,length)
    if not facing_gap and not M.blocked(x+dx*forward,y+dy*forward,radius) then return tx,ty end
    if abs(x)>M.opening/2-radius-4 then return 0,y end
    return 0,ty
end

return M
