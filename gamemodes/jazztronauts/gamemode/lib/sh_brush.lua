if SERVER then AddCSLuaFile("sh_brush.lua") end

module( "brush", package.seeall )

brush_planeside_epsilon = 0.2
SIDE_FRONT = 1
SIDE_BACK = 2

local meta = {}
meta.__index = meta

--winding is optional
function Side( plane, winding ) return setmetatable({}, meta):Init( plane, winding ) end

function meta:Init( plane, winding )

	self.plane = plane
	self.winding = winding
	self.contents = 0
	self.bevel = false
	return self

end

function meta:Copy()

	local s = Side( Plane( self.plane.normal, self.plane.dist ) )
	s.winding = self.winding:Copy()
	s.contents = self.contents
	s.bevel = self.bevel
	return s

end

function meta:Render(...)

	if self.winding then self.winding:Render(...) end

end

local meta = {}
meta.__index = meta

function Brush() return setmetatable({}, meta):Init() end

function meta:Init()

	self.sides = {}
	self.min = Vector()
	self.max = Vector()
	self.side = 0
	self.testside = 0

	ResetBoundingBox( self.min, self.max )

	return self

end

function meta:Copy()

	local b = Brush()
	for _, side in pairs(self.sides) do
		b:Add( side:Copy() )
	end
	return b

end

function meta:Add(side)

	table.insert(self.sides, side)

end

function meta:CreateFromAABB(min, max)

	for i=1, 3 do
		local normal = Vector(0,0,0)
		local dist = max[i]
		normal[i] = 1
		self:Add( Side( Plane( normal, dist ).back ) )

		normal[i] = -1
		dist = -min[i]
		self:Add( Side( Plane( normal, dist ).back ) )
	end

	return self:CreateWindings()

end

function meta:CreateWindings()

	for i, side in pairs(self.sides) do
		side.winding = poly.BaseWinding( side.plane )
		for j, other in pairs(self.sides) do
			if j ~= i and not other.bevel then
				side.winding:Clip( other.plane )
			end
		end
	end

	self:CalcBounds()

	print(#self.sides, self.min, self.max)

	return self

end

function meta:CalcBounds()

	ResetBoundingBox( self.min, self.max )

	for i, side in pairs(self.sides) do
		if side.winding then
			for j, point in pairs(side.winding.points) do
				AddPointToBoundingBox(point, self.min, self.max)
			end
		end
	end

end

function meta:MostlyOnSide(plane)
	local testside = SIDE_FRONT
	local max = 0

	for i, side in pairs(self.sides) do
		local w = side.winding
		if w ~= nil then
			for _, point in pairs(w.points) do
				local d = point:Dot( plane.normal ) - plane.dist
				if d > max then 
					max = d 
					testside = SIDE_FRONT 
				end
				if -d > max then 
					max = -d 
					testside = SIDE_BACK
				end
			end
		end
	end
	return testside

end

function meta:Split(plane)

	local dfront = 0
	local dback = 0

	for i, side in pairs(self.sides) do
		local w = side.winding
		if w ~= nil then
			for _, point in pairs(w.points) do
				local d = point:Dot( plane.normal ) - plane.dist
				if d > 0 and d > dfront then dfront = d end
				if d < 0 and d < dback then dback = d end
				--dfront = math.max(dfront, d)
				--dback = math.min(dback, d)
			end
		end
	end

	if dfront < brush_planeside_epsilon then return nil, self:Copy() end
	if dback > -brush_planeside_epsilon then return self:Copy(), nil end

	local splitwinding = poly.BaseWinding( plane )
	for _, side in pairs(self.sides) do
		splitwinding:Clip( side.plane )
	end

	if splitwinding:Area() < 1 then
		local side = self:MostlyOnSide(plane)
		--print("SMALL WINDING: " .. splitwinding:Area() .. ", " .. #splitwinding.points, side )
		if side == SIDE_FRONT then return self:Copy(), nil end
		if side == SIDE_BACK then return nil, self:Copy() end
	end

	local back = Brush()
	local front = Brush()

	for _, side in pairs(self.sides) do
		local w = side.winding

		local frontwinding, backwinding = w:Split( plane, 0 )
		if backwinding then back:Add( Side( side.plane, backwinding ) ) end
		if frontwinding then front:Add( Side( side.plane, frontwinding ) ) end
	end

	back:CalcBounds()
	front:CalcBounds()

	--************************
	--TODO: POLYGON CHECKS
	--************************

	back:Add( Side( plane.back, splitwinding:Copy() ) )
	front:Add( Side( plane, splitwinding ) )

	return front, back
end

function meta:Render(...)

	for _, side in pairs(self.sides) do
		side:Render(...)
	end

end

--[[local testBrush = Brush():CreateFromAABB( Vector(-100,-100,-100), Vector(100,100,100) )

hook.Add( "PostDrawOpaqueRenderables", "BrushLibTest", function(depth, sky)

	local dist = math.cos(CurTime()/4) * 180
	local front, back = testBrush:Split( Plane( Vector(1,1,1):GetNormal() , dist) )

	--testBrush:Render()

	if front then front:Render( Color(0,255,0), true ) end
	if back then back:Render( Color(255,0,0), true ) end

end )]]