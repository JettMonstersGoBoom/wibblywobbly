-- main.lua for curves
-- ctrl + L = load "write.test"
-- ctrl + S = save to "write.test"
-- ctrl + E = export evaluated path 
local Slab = require 'Slab'
--local SlabTest = require 'SlabTest'
local fs = require('modules/nativefs')
require('modules/ef_message')
local pow = math.pow
local rand = math.random
local math_sqrt = math.sqrt
local cos = math.cos 
local sin = math.sin 

local vec = {}
setmetatable(vec, vec);
function vec:__call(a,b)local d={}vec.__index=self;setmetatable(d,self)d.x=a or 0;d.y=b or 0;return d end
function vec:__tostring()return string.format("(%03f,%03f,%d)",self.x,self.y,self.link)end
function vec:__len() return self:length() end
function vec:__add(a)return vec(self.x+a.x,self.y+a.y)end
function vec:__sub(right) return vec(self.x - right.x,self.y - right.y)end
function vec:__div(right) return vec(self.x / right.x,self.y / right.y)end
function vec:length() return math_sqrt(self.x * self.x + self.y * self.y) end
function vec:distance(to) a = self - to return self.__len(a) end
function vec:dot(x,y) return (self.x * x + self.y * y) end

function vec:angle(v)
  return math.atan2(v.x - self.x,v.y - self.y)
end


function addToSet(set, key)
	set[key] = true
end

function removeFromSet(set, key)
	set[key] = nil
end

function setContains(set, key)
	return set[key] ~= nil
end


function circle( cx, cy, r ) gr.circle( 'line', cx, cy, r, r ) end

local Catmull = {}

Catmull.Points = {}
Catmull.Keys = {}

function Catmull:Load(filename)
	Catmull.Points = {}
	Catmull.Keys = {}
	index = 1
	for line in fs.lines(filename) do
		if #line>1 then 
			res = Split(line,":")
			if res[1]=='S' then	
				SmoothSteps = tonumber(res[2])
			end
			if res[1]=='C' then	
				table.insert(Catmull.Points,vec(tonumber(res[2]),tonumber(res[3])))
			end
			if res[1]=='K' then	
				addToSet(Catmull.Keys,tonumber(res[2]))
			end
		end
	end
	Catmull:Smooth(Catmull.Points,SmoothSteps)
end

function Catmull:Save(filename)
	local f = fs.newFile(filename)
	f:open('w')
	f:write("S:" .. SmoothSteps .. "\n")

	for pi=1,#Catmull.Points do
		f:write("C:" .. Catmull.Points[pi].x .. ":" .. Catmull.Points[pi].y .. "\n")
	end

	for _, value in pairs(Catmull.Keys) do
		if value==true then
			f:write("K:" .. _ .. "\n")
		end
	end

	f:close()
end

function Catmull:Export(filename)
	local f = fs.newFile(filename)
	f:open('w')

	sx = smoothed_points[1].x
	sy = smoothed_points[1].y

	for pi=1,#smoothed_points do
		cx=smoothed_points[pi].x
		cy=smoothed_points[pi].y
		f:write("\t.word " .. math.floor(cx-sx) .. "," .. math.floor(cy-sy) .. "\n")
		sx = cx 
		sy = cy
	end
	f:close()
end

function Catmull:Smooth( points, steps )
	if #points < 3 then return points end
	local steps = steps or 5
	local spline = {}
	local count = #points - 1
	local p0, p1, p2, p3, x, y
	for i = 1, count do
		 if i == 1 then
				p0, p1, p2, p3 = Catmull.Points[i], Catmull.Points[i], Catmull.Points[i + 1], Catmull.Points[i + 2]
				elseif
				i == count then
				p0, p1, p2, p3 = Catmull.Points[#points - 2], Catmull.Points[#points - 1], Catmull.Points[#points], Catmull.Points[#points]
				else
				p0, p1, p2, p3 = Catmull.Points[i - 1], Catmull.Points[i], Catmull.Points[i + 1], Catmull.Points[i + 2]
				end
		 for t = 0, 1, 1 / steps do
				x = 0.5*((2*p1.x)+(p2.x-p0.x)*t+(2*p0.x-5*p1.x+4*p2.x-p3.x)*t*t+(3*p1.x-p0.x-3*p2.x+p3.x)*t*t*t)
				y = 0.5*((2*p1.y)+(p2.y-p0.y)*t+(2*p0.y-5*p1.y+4*p2.y-p3.y)*t*t+(3*p1.y-p0.y-3*p2.y+p3.y )*t*t*t)
				--prevent duplicate entries
				if not(#spline > 0 and spline[#spline].x == x and spline[#spline].y == y) then
					 table.insert( spline , vec(x , y) ) -- table of indexed points
					 end
				end
		 end
	return spline
end



shift = false
ctrl = false 
alt = false 
local curvesteps = 0.05

t = 0.0
-- make random points

mouse_cursor = vec(0,0)
last_mouse_cursor = vec(0,0)
selection = -1 
key_selection = -1
lastmoved = 4
hit = 0 
Point_Over = 0
Key_Over = 0

local DrawDialog_FileDialog = ''
local DrawDialog_FileDialog_Result = ""

function MainMenuBar()
	if Slab.BeginMainMenuBar() then
		if Slab.BeginMenu("File") then
			if Slab.MenuItem("Load Points") then 
				DrawDialog_FileDialog = 'openfile'
				DrawDialog_ExtraType = "lpnts"
				DrawDialog_Filter = {"*.pnts", "points files"}
			end
			if Slab.MenuItem("Save Points") then 
				DrawDialog_FileDialog = 'savefile'
				DrawDialog_ExtraType = "spnts"
				DrawDialog_Filter = {"*.pnts", "points files"}
			end

			if Slab.MenuItem("Export ASM") then 
				DrawDialog_FileDialog = 'savefile'
				DrawDialog_ExtraType = "asm"
				DrawDialog_Filter = {"*.asm", "assembly"}
			end
			if Slab.MenuItem("Quit") then
				love.event.quit()
			end

			Slab.EndMenu()
		end
--		Slab.Text("scale " .. scene.camera_scale)
	
		Slab.EndMainMenuBar()
	end

	--	file dialog 
	if DrawDialog_FileDialog ~= '' then
		local Result = Slab.FileDialog({AllowMultiSelect = false, Type = DrawDialog_FileDialog, Filters = DrawDialog_Filter})
		if Result.Button ~= "" then
			if Result.Button == "OK" then
				DrawDialog_FileDialog_Result = Result.Files[1]
				--	load
				if DrawDialog_ExtraType == 'lpnts' then 
					Catmull:Load(DrawDialog_FileDialog_Result)
				end
				--	save 
				if DrawDialog_ExtraType == 'spnts' then 
					Catmull:Save(DrawDialog_FileDialog_Result)
				end

				if DrawDialog_ExtraType == 'asm' then 
					Catmull:Export(DrawDialog_FileDialog_Result)
				end
			end
			DrawDialog_FileDialog = ''

		end
	end
end


function love.load()
	
	gr = love.graphics
--	gr.setCaption( "Bezier vs Cubic Spline Curve Fitting" )
	gr.setBackgroundColor( 0,0,0, 255 )
	
	Slab.Initialize(args)

end

SmoothSteps = 12


function love.update(dt)
	Slab.Update(dt)
	MainMenuBar()

	Slab.BeginWindow('SlabTest', {Title = "Slab", AutoSizeWindow = false, W = 256.0, H = 256.0})
	if Slab.InputNumberDrag('SmoothSteps', SmoothSteps, 1, 64, 1, {W = 50}) then
		SmoothSteps = Slab.GetInputNumber()
	end
	Slab.EndWindow()
end

function love.draw()

	mouse_cursor.x,mouse_cursor.y = Slab.GetMousePosition()

	Point_Over = -1 

	-- figure out which control point the moust is close to 
	for pt=1,#Catmull.Points do 
		f = mouse_cursor:distance(Catmull.Points[pt])
		gr.setColor(0,128,128,255)
		if f<10 then 
			gr.setColor(255,255,255,255)
			Point_Over = pt
		end 
		circle(Catmull.Points[pt].x,Catmull.Points[pt].y,10)
	end
	--	create smooth list from control points
	smoothed_points = Catmull:Smooth(Catmull.Points,SmoothSteps)

	--	display the key frames	
	for _, value in pairs(Catmull.Keys) do
		if smoothed_points[_] ~=nil then
			circle(smoothed_points[_].x,smoothed_points[_].y,5)
		end
	end
	--	figure out which keyframe the mouse is close to 
	Key_Over = -1
	for pt=1,#smoothed_points-1 do 
		f = mouse_cursor:distance(smoothed_points[pt])
		gr.setColor(0,0,128,255)
		size = 2
		if (f<3) then 
			gr.setColor(255,0,128,255)
			size = 5
			Key_Over = pt
		end
		
		gr.line(smoothed_points[pt].x,smoothed_points[pt].y-size,smoothed_points[pt].x,smoothed_points[pt].y+size)
		gr.line(smoothed_points[pt].x-size,smoothed_points[pt].y,smoothed_points[pt].x+size,smoothed_points[pt].y)

		gr.setColor(192,182,128,255)
		--	display the line 	
		gr.line(smoothed_points[pt].x,smoothed_points[pt].y,smoothed_points[pt+1].x,smoothed_points[pt+1].y)
	end

	--	follow the path and display triggers 
	if #smoothed_points>2 then 
		t=t%(#smoothed_points-1)
		t=t+1
		it = 1+math.floor(t)
		if setContains(Catmull.Keys,it) then 
			gr.line(smoothed_points[it].x,smoothed_points[it].y-50,smoothed_points[it].x,smoothed_points[it].y+50)
			ef_addMessage('Trigger!',smoothed_points[it].x, smoothed_points[it].y-8, 'up')
		end
		circle(smoothed_points[it].x,smoothed_points[it].y,10)
	end


	dx = mouse_cursor.x - last_mouse_cursor.x
	dy = mouse_cursor.y - last_mouse_cursor.y

	if (selection~=-1) then 
		Catmull.Points[selection].x=Catmull.Points[selection].x + (dx)
		Catmull.Points[selection].y=Catmull.Points[selection].y + (dy)
		lastmoved = selection
	end

	last_mouse_cursor.x = mouse_cursor.x
	last_mouse_cursor.y = mouse_cursor.y

	ef_printMessages()

	Slab.Draw()


end

function love.mousemoved(mx,my,button)
	mouse_cursor.x = mx 
	mouse_cursor.y = my
end
function love.mousereleased(mx,my)
	hit = 0
	selection = -1
	if Key_Over == -1 then 
		key_selection = -1
	end
end
function love.mousepressed(mx, my, button)
	mouse_cursor.x = mx 
	mouse_cursor.y = my

	if (button==1) then
		hit = 1
		selection = Point_Over

		if Key_Over~=-1 and shift==true then
			if setContains(Catmull.Keys,Key_Over)==false then 
				addToSet(Catmull.Keys,Key_Over)
			else 
				removeFromSet(Catmull.Keys,Key_Over)
			end
		end
	end

	if (button==2) then 
		np = vec(mouse_cursor.x,mouse_cursor.y)
		table.insert(Catmull.Points,np)
	end
end

function Split(s, delimiter)
	result = {};
	for match in (s..delimiter):gmatch("(.-)"..delimiter) do
			table.insert(result, match);
	end
	return result;
end

function love.keypressed( key )
	if key == "escape" then love.event.quit() end
	shift = love.keyboard.isDown( 'lshift' ) or love.keyboard.isDown('rshift')
	ctrl = love.keyboard.isDown( 'lctrl' ) or love.keyboard.isDown('rctrl')
	alt = love.keyboard.isDown( 'lalt' ) or love.keyboard.isDown('ralt')
	if key=='delete' then 
		if Point_Over ~=-1 then 
			table.remove(Catmull.Points, Point_Over)
		end
	end
end

function love.keyreleased(key, scancode)
	shift = love.keyboard.isDown( 'lshift' ) or love.keyboard.isDown('rshift')
	ctrl = love.keyboard.isDown( 'lctrl' ) or love.keyboard.isDown('rctrl')
	alt = love.keyboard.isDown( 'lalt' ) or love.keyboard.isDown('ralt')
end


