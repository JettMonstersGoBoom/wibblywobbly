ef_timeElapsed = 0
ef_nowTime = 0

ef_messageOpts = { fadeStep = 32, displayTime = .5}
ef_messages = {}

function ef_addMessage(text, xpos, ypos, direction)
	number = #ef_messages+1
	ef_messages[number] = { message = text,x = xpos, y = ypos, alpha = 255, type = 'get', direction = direction, startedAt = love.timer.getTime() }
end

function ef_printMessages()
	if #ef_messages > 0 then
		for i=1, #ef_messages do
			if ef_messages[i]['alpha'] > 0 then
				love.graphics.setColor( 255, 255, 255, ef_messages[i]['alpha'] )
				love.graphics.print(ef_messages[i]['message'],ef_messages[i]['x'],ef_messages[i]['y'])
				love.graphics.setColor( 255, 255, 255, 100 )
				love.graphics.print(ef_messages[i]['message'],ef_messages[i]['x']+1,ef_messages[i]['y']+1)
				if (love.timer.getTime() - ef_messages[i]['startedAt']) > ef_messageOpts['displayTime'] then
					ef_messages[i]['alpha'] = ef_messages[i]['alpha'] - ef_messageOpts['fadeStep'];
				end
				if(ef_messages[i]['direction'] == 'up') then
					ef_messages[i]['y'] = ef_messages[i]['y'] - 1;
				end
				if(ef_messages[i]['direction'] == 'down') then
					ef_messages[i]['y'] = ef_messages[i]['y'] + 1;
				end
				if(ef_messages[i]['direction'] == 'left') then
					ef_messages[i]['x'] = ef_messages[i]['x'] - 1;
				end
				if(ef_messages[i]['direction'] == 'right') then
					ef_messages[i]['x'] = ef_messages[i]['x'] + 1;
				end
			end
			love.graphics.setColor( 255, 255, 255, 255 )
		end
	end
end
