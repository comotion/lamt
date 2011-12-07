local assert , error = assert , error
local strsub = string.sub
local tblinsert , tblconcat = table.insert , table.concat


-- Inserts the given string (block) at the current position in the file; moving all other data down.
-- Uses BLOCKSIZE chunks
local function file_insert ( fd , block , BLOCKSIZE )
	BLOCKSIZE = BLOCKSIZE or 2^20
	assert ( #block <= BLOCKSIZE )

	while true do
		local nextblock , e = fd:read ( BLOCKSIZE )

		local seekto
		if nextblock ~= nil then
			assert ( fd:seek ( "cur" , -#nextblock ) )
		elseif e then
			error ( e )
		end

		assert ( fd:write ( block ) )
		if nextblock == nil then break end
		assert ( fd:write ( strsub ( nextblock , 1 , BLOCKSIZE-#block ) ) )
		assert ( fd:flush ( ) )
		block = strsub ( nextblock , BLOCKSIZE-#block+1 , -1 )
	end
	assert ( fd:flush ( ) )
end

local function get_from_string ( s , i )
	i = i or 1
	return function ( n )
		i = i + n
		if i > #s then return error ( "Unable to read enough characters" ) end
		return strsub ( s , i-n , i-1 )
	end , function ( new_i )
		if new_i then i = new_i end
		return i
	end
end

local function get_from_fd ( fd )
	return function ( n )
		local r = assert ( fd:read ( n ) )
		if #r < n then return error ( "Unable to read enough characters" ) end
		return r
	end , function ( newpos )
		if newpos then return assert ( fd:seek ( "set" , newpos ) ) end
		return assert ( fd:seek ( ) )
	end
end

	end
end

local function read_terminated_string ( get , terminator )
	terminator = terminator or "\0"
	local str = { }
	while true do
		local c = get ( 1 )
		if c == terminator then break end
		tblinsert ( str , c )
	end
	return tblconcat ( str )
end

return {
	file_insert = file_insert ;

	get_from_string = get_from_string ;
	get_from_fd = get_from_fd ;

	read_terminated_string = read_terminated_string ;
}
