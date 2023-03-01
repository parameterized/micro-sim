
json = require 'json'

f16 = love.graphics.newFont(16)
f20 = love.graphics.newFont(20)

function love.load()
	ssx, ssy = love.graphics.getDimensions()

	frameFolder = 'microscope/micro1/processed_frames'
	trackFilepath = 'track-micro1.json'
	
	numFrames = 9413

	frameNum = 0
	loadFrame()

	scrubbing = false
	playing = false
	frameTimer = 0
	vidFPS = 25
	slow = false
	slowFactor = 2

	maxArrowTimer = 0.5
	arrowTimer = maxArrowTimer
	arrowFrameTimer = 0
	arrowShiftSpeed = 10

	-- first letters should be unique
	trackKeys = {'body', 'head', 'world'}
	track = {jumps={}}
	for _, k in pairs(trackKeys) do
		track[k] = {}
		for i=1, numFrames do
			track[k][i] = {100, 100}
		end
	end
	jumpSet = {}
	tracking = nil

	showControls = true
end

function loadFrame()
	framePath = frameFolder .. '/' .. frameNum .. '.jpg'
	if love.filesystem.getInfo(framePath) ~= nil then
		frameImg = love.graphics.newImage(framePath)
	end
end

function loadJumpSet()
	-- load list into set
	jumpSet = {}
	for _, k in pairs(track.jumps) do
		jumpSet[k + 1] = true
	end
end

function saveJumpSet()
	-- convert to list
	track.jumps = {}
	for k, _ in pairs(jumpSet) do
		table.insert(track.jumps, k - 1)
	end
end

function love.mousepressed(x, y, btn)
	if btn == 1 then
		if x > 10 and x < ssx - 10 and y > ssy - 30 and y < ssy - 10 then
			scrubbing = true
		end
	end
end

function love.mousereleased(x, y, btn)
	if btn == 1 then
		scrubbing = false
	end
end

function love.keypressed(k)
	if k == 'space' then
		playing = not playing
	elseif k == 's' then
		if love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl') then
			saveJumpSet()
			trackJson = json.encode(track)
			local f = io.open(trackFilepath, 'w')
			f:write(trackJson)
			f:close()
		elseif love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift') then
			slow = not slow
		end
	elseif k == 'o' then
		if love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl') then
			local f = io.open(trackFilepath, 'r')
			track = json.decode(f:read('*all'))
			f:close()
			loadJumpSet()
		end
	elseif k == 'j' then
		if jumpSet[frameNum + 1] then
			jumpSet[frameNum + 1] = nil
		else
			jumpSet[frameNum + 1] = true
		end
	elseif k == '0' then
		frameNum = 0
		loadFrame()
	elseif k == '/' and
	(love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift')) then
		showControls = not showControls
	end

	for _, trackKey in ipairs(trackKeys) do
		if k == trackKey:sub(1, 1) then
			if tracking == trackKey then
				tracking = nil
			else
				tracking = trackKey
			end
		end
	end
end

function love.update(dt)
	if playing and not scrubbing then
		frameTimer = frameTimer - dt / (slow and slowFactor or 1)
		if frameTimer < 0 then
			frameTimer = frameTimer + 1 / vidFPS
			frameNum = (frameNum + 1) % numFrames
			loadFrame()
		end
	end

	local mx, my = love.mouse.getPosition()
	if love.mouse.isDown(1) then
		if scrubbing then
			frameNum = math.floor((numFrames - 1) * (mx - 10) / (ssx - 20) + 0.5)
			frameNum = math.min(math.max(frameNum, 0), numFrames - 1)
			loadFrame()
		end
	end

	if tracking ~= nil then
		track[tracking][frameNum + 1] = {mx, my}
	end

	local r = love.keyboard.isDown('right')
	local l = love.keyboard.isDown('left')
	if r or l then
		if not playing and not scrubbing then
			if arrowTimer < 0 then
				arrowFrameTimer = arrowFrameTimer - dt
			end
			if (arrowTimer == maxArrowTimer or
			arrowTimer < 0 and arrowFrameTimer < 0) then
				if arrowFrameTimer < 0 then
					arrowFrameTimer = arrowFrameTimer + 1 / vidFPS
				end
				frameNum = (frameNum - (
					(love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift'))
					and arrowShiftSpeed or 1
				) * (r and -1 or 1)) % numFrames
				loadFrame()
			end
			arrowTimer = arrowTimer - dt
		end
	else
		arrowTimer = maxArrowTimer
		arrowFrameTimer = 0
	end

	collectgarbage()
end

function love.draw()
	love.graphics.clear(0.5, 0.5, 0.5)

	-- tracking points
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(frameImg)
	for _, k in ipairs(trackKeys) do
		local x, y = unpack(track[k][frameNum + 1])
		love.graphics.setColor(0.3, 0.3, 0.8, 0.2)
		love.graphics.circle('fill', x, y, 9)
		love.graphics.setColor(0, 0, 0)
		love.graphics.circle('line', x, y, 9)
		love.graphics.setColor(1, 1, 1, 0.6)
		love.graphics.circle('fill', x, y, 3)
		love.graphics.setColor(0, 0, 0)
		love.graphics.circle('line', x, y, 3)
		local name = k
		if name == 'world' and jumpSet[frameNum + 1] then
			name = name .. ' (jump frame)'
		end
		love.graphics.setColor(0.3, 0.3, 0.8, 0.5)
		love.graphics.rectangle('fill', x + 12, y - 16, f20:getWidth(name) + 8, 24)
		love.graphics.setColor(1, 1, 1)
		love.graphics.setFont(f20)
		love.graphics.print(name, x + 16, y - 16)
	end

	-- timeline
	love.graphics.setColor(0.2, 0.4, 0.7)
	love.graphics.rectangle('fill', 10, ssy - 30, (ssx - 20) * frameNum / (numFrames - 1), 20)	
	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle('line', 10, ssy - 30, ssx - 20, 20)

	-- controls
	if showControls then
		love.graphics.setColor(0, 0, 0)
		love.graphics.setFont(f16)
		love.graphics.print(
			'Controls: (toggle visibility with "?")\n'
			.. 'Click and drag to scrub the timeline\n'
			.. 'Right/Left: Step frame forward/backward,\n'
			.. '\thold to keep stepping\n'
			.. 'Shift + Right/Left: Step 10 frames\n'
			.. 'Space: Play/Pause\n'
			.. 'Shift + S: Toggle slow playback\n'
			.. '0: Go to frame 0\n'
			.. 'B/H/W: Toggle tracking body/head/world\n'
			.. 'J: Mark as jump frame\n'
			.. '\t(start tracking another world point)\n'
			.. 'Ctrl + S: Save tracking file\n'
			.. 'Ctrl + O: Load tracking file',
			920, 10
		)
	end
end
