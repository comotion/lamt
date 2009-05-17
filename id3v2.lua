--[[
	LOMP ( Lua Open Music Player )
	Copyright (C) 2007- daurnimator

	This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

require "general"

module ( "lomp.fileinfo.id3v2" , package.see ( lomp ) )

pcall ( require , "luarocks.require" ) -- Activates luarocks if available.
require "vstruct"
require "iconv"
local genrelist = require "modules.fileinfo.genrelist"

_NAME = "ID3v2 tag reader/writer"
-- http://www.id3.org/id3v2.4.0-structure

local function desafesync ( tbl )
	local new = { }
	for i = 1 , #tbl do
		if i % 8 ~= 0 then
			table.insert ( new , tbl [ i ] )
		end
	end
	return vstruct.implode ( new )
end

local function utf8 ( str , encoding )
	if not encoding then encoding = "ISO-8859-1" end
	return iconv.new ( "UTF-8" ,  encoding ):iconv ( str )
end

local function readheader ( fd )
	local t = vstruct.unpack ( "> ident:s3 version:u1 revision:u1 flags:m1 safesyncsize:m4" , fd )
	if ( t.ident == "ID3" or t.ident == "3DI" ) then
		t.size = desafesync ( t.safesyncsize )
		t.safesyncsize = nil -- Don't need to keep this.
		t.firstframeoffset = fd:seek ( "cur" )
		return t
	else
		return false , "Not an ID3v2 header/footer"
	end
end

local frameencode = {
	[ "uniquefileid" ] = "UFID" ,
	[ "content group" ] = "TIT1" ,
	[ "title" ] = "TIT2" ,
	[ "subtitle" ] = "TIT3" ,
	[ "album" ] = "TALB" ,
	[ "original album" ] = "TOAL" ,
	[ "tracknumber" ] = function ( item )
						local t = { }
						for i , v in ipairs ( item ["tracknumber"] or { } ) do
							if item ["totaltracks"] [i] then
								table.insert ( t , tostring ( v ) .. "/" .. item ["totaltracks"] [i] )
							else
								table.insert ( t , tostring ( v ) ) 
							end	
						end
						return "TRCK" , t
					end ,
	[ "totaltracks" ] = function ( item )
						if not item ["tracknumber"] [i] then -- If not going to put in with tracknumber in TRCK, put in TXXX
							return "TXXX"
						end
					end ,
	[ "discnumber" ] = function ( item )
						local t = { }
						for i , v in ipairs ( item ["discnumber"] or { } ) do
							if item ["totaldiscs"] [i] then
								table.insert ( t , tostring ( v ) .. "/" .. item ["totaldiscs"] [i] )
							else
								table.insert ( t , tostring ( v ) ) 
							end	
						end
						return "TPOS" , t
					end ,	
	[ "totaldiscs" ] = function ( item )
						if not item ["discnumber"] [i] then -- If not going to put in with discnumber in TPOS, put in TXXX
							return "TXXX"
						end
					end ,
	[ "set subtitle" ] = "TSST" ,
	[ "isrc" ] = "TSRC" ,

	[ "artist" ] = "TPE1" ,
	[ "band" ] = "TPE2" ,
	[ "conductor" ] = "TPE3" , 
	[ "remixed by" ] = "TPE4" ,
	[ "original artist" ] = "TOPE" ,
	[ "writer" ] = "TEXT" ,
	[ "original writer" ] = "TOLY" ,
	[ "composer" ] = "TCOM" ,
	-- TODO: TMCL (list) -- Some sort of metatable? need to match things ending in "player"
	-- TODO: TIPL (list) -- metatable? could be anything though...
	[ "encoded by" ] = "TENC" ,
	
	[ "bpm" ] = "TBPM" ,
	[ "length" ] = "TLEN" ,
	[ "musical key" ] = "TKEY" ,
	[ "language" ] = "TLAN" ,
	[ "genre" ] = "TCON" , -- Special
	[ "file type" ] = "TFLT" , -- Special
	[ "media type" ] = "TMED" , -- Special
	[ "mood" ] = "TMOO" ,
	[ "copyright" ] = "TCOP" , -- Special
	[ "produced" ] = "TPRO" , -- Special
	[ "publisher" ] = "TPUB" ,
	[ "owner" ] = "TOWN" ,
	[ "radio station" ] = "TRSN" ,
	[ "radio station owner" ] = "TRSO" ,
	
	[ "publisher" ] = "TOFN" ,
	--[ "delay" ] = "TDLY" , -- Special
	[ "encoding time" ] = "TDEN" , -- Special: Time
	[ "original release time" ] = "TDOR" , -- Special: Time
	[ "recorded" ] = "TDRC" , -- Special: Time
	[ "release time" ] = "TDRL" , -- Special: Time
	[ "tagged" ] = "TDTG" , -- Special: Time
	[ "encoder settings" ] = "TSSE" ,
	[ "album sort order" ] = "TSOA" ,
	[ "performer sort order" ] = "TSOP" ,
	[ "title sort order" ] = "TSOT" ,
	
	[ "commercial information url" ] = "WCOM" ,
	[ "copyright url" ] = "WCOP" ,
	[ "file webpage url" ] = "WOAF" ,
	[ "artist webpage url" ] = "WOAR" ,
	[ "source webpage url" ] = "WOAS" , 
	[ "internet radio webpage url" ] = "WORS" , 
	[ "payment url" ] = "WPAY" , 
	[ "publisher url" ] = "WPUB" ,
	
	[ "cd toc" ] = "MCDI" ,
	
	-- ETCO -- Event timing codes
	-- MLLT -- Not applicable
	-- SYTC -- Synchronised tempo codes
	
	[ "lyrics" ] = function ( item )
		-- TODO
		return "USLT"
	end ,
	
	-- SYLT -- Synchronised lyrics/text
	
	-- Comment
	["comment"] = function ( str )
		-- TODO
		return "COMM"
	end ,
	
	-- RVA2 -- Relative volume adjustment (2)
	-- EQU2 -- Equalisation (2)
	-- RVRB -- Reverb
	
	-- APIC -- Attached pictures
	
	-- GEOB -- General encapsulated object

	-- PCNT -- Play counter
	-- POPM -- Popularimeter
	
	-- RBUF -- Recommended buffer size

	-- AENC -- Audio encryption

	-- LINK -- Linked information

	-- POSS -- Position synchronisation frame
	
	-- Terms of use frame
	[ "terms of use" ] = function ( item )
		return "USER"
	end ,
	
	-- OWNE -- Ownership frame
	-- COMR -- Commericial frame
	
	-- ENCR -- Encryption method registration
	-- GRID -- Group identification registration

	-- PRIV -- Private frame
	-- SIGN -- Signature frame

	-- SEEK -- Seek frame
	
	-- ASPI -- Audio seek point index
}

local encodings = {
	[ 0 ] = { name = "ISO-8859-1" , nulls = "1" } , 
	[ 1 ] = { name = "UTF-16" , nulls = "2" } , 
	[ 2 ] = { name = "UTF-16BE" , nulls = "2" } , 
	[ 3 ] = { name = "UTF-8" , nulls = "1" } , 
}

local function readtextframe ( str )
	local t = vstruct.unpack ( "> encoding:u1 text:s" .. #str , str )
	local st = string.explode ( t.text , string.rep ( "\0" , encodings [ t.encoding ].nulls ) )
	for i , v in ipairs ( st ) do
		st [ i ] = utf8 ( v , encodings [ t.encoding ].name )
	end
	return st
end

local framedecode = {
	["UFID"] = function ( str )
			return vstruct.unpack ( "> ownerid:{ z } uniquefileid:{ s64 }" , str )
		end ,
		
	-- TEXT fields
	-- Identification frames
	["TIT1"] = function ( str ) -- Content group description
			return { [ "content group" ] = readtextframe ( str ) }
		end ,
	["TIT2"] = function ( str ) -- Title/Songname/Content description
			return { [ "title" ] = readtextframe ( str ) }
		end ,
	["TIT3"] = function ( str ) -- Subtitle/Description refinement
			return { [ "subtitle" ] = readtextframe ( str ) }
		end ,
	["TALB"] = function ( str ) -- Album/Movie/Show title
			return { [ "album" ] = readtextframe ( str ) }
		end ,
	["TOAL"] = function ( str ) -- Original album/movie/show title
			return { [ "original album" ] = readtextframe ( str ) }
		end ,
	["TRCK"] = function ( str ) -- Track number/Position in set
			local track , total = { } , { }
			for i , v in ipairs ( readtextframe ( str ) ) do
				track [ #track + 1 ] , total [ #total + 1 ] = string.match ( v , "([^/]*)/?(.*)" )
			end
			return { [ "tracknumber" ] = track , ["totaltracks"] = total }
		end ,
	["TPOS"] = function ( str ) -- Part of a set
			local disc , total = { } , { }
			for i , v in ipairs ( readtextframe ( str ) ) do
				disc [ #disc + 1 ] , total [ #total + 1 ] = string.match ( v , "([^/]*)/?(.*)" )
				if total [ #total ] == "" then total [ #total ] = nil end -- string match still fills in the total array
			end
			return { [ "discnumber" ] = disc , ["totaldiscs"] = total }
		end ,
	["TSST"] = function ( str ) -- Set subtitle
			return { [ "set subtitle" ] = readtextframe ( str ) }
		end ,
	["TSRC"] = function ( str ) -- ISRC
			return { [ "ISRC" ] = readtextframe ( str ) }
		end ,
	-- Involved persons frames
	["TPE1"] = function ( str ) -- Lead artist/Lead performer/Soloist/Performing group
		return { [ "artist" ] = readtextframe ( str ) }
	end ,
	["TPE2"] = function ( str ) -- Band/Orchestra/Accompaniment
		return { [ "band" ] = readtextframe ( str ) }
	end ,
	["TPE3"] = function ( str ) -- Conductor
		return { [ "conductor" ] = readtextframe ( str ) }
	end ,
	["TPE4"] = function ( str ) -- Interpreted, remixed, or otherwise modified by
		return { [ "remixed by" ] = readtextframe ( str ) }
	end ,
	["TOPE"] = function ( str ) -- Original artist/performer
		return { [ "original artist" ] = readtextframe ( str ) }
	end ,
	["TEXT"] = function ( str ) -- Lyricist/Text writer
		return { [ "writer" ] = readtextframe ( str ) }
	end ,
	["TOLY"] = function ( str ) -- Original lyricist/text writer
		return { [ "original writer" ] = readtextframe ( str ) }
	end ,
	["TCOM"] = function ( str ) -- Composer
		return { [ "composer" ] = readtextframe ( str ) }
	end ,
	["TMCL"] = function ( str ) -- Musician credits list
		local t , field = {} , ""
		for i , v in ipairs ( readtextframe ( str ) ) do
			if i % 2 == 1 then -- odd, field is instrument
				field = v .. " player"
				t [ field ] = t [ field ] or { }
			else -- even, is musician's name
				t [ field ] [ #t [ field ] ] = v
			end
		end
		return t
	end ,
	["TIPL"] = function ( str ) -- Involved people list
		local t , field = {} , ""
		for i , v in ipairs ( readtextframe ( str ) ) do
			if i % 2 == 1 then -- odd, field is instrument
				field = v
				t [ field ] = t [ field ] or { }
			else -- even, is musician's name
				t [ field ] [ #t [ field ] ] = v
			end
		end
		return t
	end ,
	["TENC"] = function ( str ) -- Encoded by
		return { [ "encoded by" ] = readtextframe ( str ) }
	end ,
	-- Derived and subjective properties frames
	["TBPM"] = function ( str ) -- BPM
		return { [ "bpm" ] = readtextframe ( str ) }
	end ,
	["TLEN"] = function ( str ) -- Length
		return { [ "length" ] = readtextframe ( str ) }
	end ,
	["TKEY"] = function ( str ) -- Initial key
		return { [ "musical key" ] = readtextframe ( str ) }
	end ,
	["TLAN"] = function ( str ) -- Language
		return { [ "language" ] = readtextframe ( str ) }
	end ,
	["TCON"] = function ( str ) -- Content type
		local t = readtextframe ( str )
		for i , v in ipairs ( t) do
			if v == "RX" then t [ i ] = "Remix"
			elseif v == "CR" then t [ i ] = "Cover" 
			elseif tonumber ( v ) then
				t [ i ] = genrelist [ tonumber ( v ) ]
			end
		end
		return { [ "genre" ] = t }
	end ,
	["TFLT"] = function ( str ) -- File Type
		local t = readtextframe ( str )
		if not next ( t ) then t[1] = "MPG" end -- TODO: interpret further
		return { [ "file type" ] = t }
	end ,
	["TMED"] = function ( str ) -- Media type
		return { [ "media type" ] = readtextframe ( str ) } -- TODO: interpret media type
	end ,
	["TMOO"] = function ( str ) -- Mood
		return { [ "mood" ] = readtextframe ( str ) }
	end ,
	-- Rights and license frames
	["TCOP"] = function ( str ) -- Copyright message
		local c = { }
		for i , v in ipairs ( readtextframe ( str ) ) do
			local m = string.match ( v , "(%d%d%d%d)%s" )
			if m then 
				c [ #c ] = "Copyright " .. m
			end
		end
		return { [ "copyright" ] =  c }
	end ,
	["TPRO"] = function ( str ) -- Produced notice
		local p = { }
		for i , v in ipairs ( readtextframe ( str ) ) do
			local m = string.match ( v , "(%d%d%d%d)%s" )
			if m then 
				p [ #p ] = "Produced " .. m
			end
		end
		return { [ "produced" ] =p }
	end ,
	["TPUB"] = function ( str ) -- Publisher
		return { [ "publisher" ] = readtextframe ( str ) }
	end ,
	["TOWN"] = function ( str ) -- File owner/licensee
		return { [ "owner" ] = readtextframe ( str ) }
	end ,
	["TRSN"] = function ( str ) -- Internet radio station name
		return { [ "radio station" ] = readtextframe ( str ) }
	end ,
	["TRSO"] = function ( str ) -- Internet radio station owner
		return { [ "radio station owner" ] = readtextframe ( str ) }
	end ,
	-- Other text frames
	["TOFN"] = function ( str ) -- Original filename
		return { [ "original filename" ] = readtextframe ( str ) }
	end ,
	--[[["TDLY"] = function ( str ) -- Playlist delay
		return { [ "delay" ] = readtextframe ( str ) }
	end ,--]]
	["TDEN"] = function ( str ) -- Encoding time
		-- TODO: is a timestamp
		return { [ "encoding time" ] = readtextframe ( str ) }
	end ,
	["TDOR"] = function ( str ) -- Original release time
		-- TODO: is a timestamp
		return { [ "original release time" ] = readtextframe ( str ) }
	end ,
	["TDRC"] = function ( str ) -- Recording time
		-- TODO: is a timestamp
		return { [ "date" ] = readtextframe ( str ) }
	end ,
	["TDRL"] = function ( str ) -- Release time
		-- TODO: is a timestamp
		return { [ "release time" ] = readtextframe ( str ) }
	end ,
	["TDTG"] = function ( str ) -- Tagging time
		-- TODO: is a timestamp
		return { [ "tagged" ] = readtextframe ( str ) }
	end ,
	["TSSE"] = function ( str ) -- Software/Hardware and settings used for encoding
		return { [ "encoder settings" ] = readtextframe ( str ) }
	end ,
	["TSOA"] = function ( str ) -- Album sort order
		return { [ "album sort order" ] = readtextframe ( str ) }
	end ,
	["TSOP"] = function ( str ) -- Performer sort order
		return { [ "performer sort order" ] = readtextframe ( str ) }
	end ,
	["TSOT"] = function ( str ) -- Title sort order
		return { [ "title sort order" ] = readtextframe ( str ) }
	end ,
	-- Special case, TXXX
	["TXXX"] = function ( str ) -- Custom text frame
		local t = vstruct.unpack ( "> encoding:u1 field:z text:s" .. #str , str )
		t.text = string.match ( t.text  , "^%z*(.*)" ) or "" -- Strip any leading nulls
		local st = string.explode ( t.text , string.rep ( "\0" , encodings [ t.encoding ].nulls ) )
		for i , v in ipairs ( st ) do
			st [ i ] = utf8 ( v , encodings [ t.encoding ].name )
		end
		return { [ t.field ] =  st }
	end ,
	
	-- URL fields,
	["WCOM"] = function ( str ) -- Commerical information
		return { ["commercial information url"] = { str } }
	end ,
	["WCOP"] = function ( str ) -- Copyright/Legal information
		return { ["copyright url"] = { str } }
	end ,
	["WOAF"] = function ( str ) -- Official audio file webpage
		return { ["file webpage url"] = { str } }
	end ,
	["WOAR"] = function ( str ) -- Official artist/performer webpage
		return { ["artist webpage url"] = { str } }
	end ,
	["WOAS"] = function ( str ) -- Official audio source webpage
		return { ["source webpage url"] = { str } }
	end ,
	["WORS"] = function ( str ) -- Official Internet radio station homepage
		return { ["internet radio webpage url"] = { str } }
	end ,
	["WPAY"] = function ( str ) -- Payment
		return { ["payment url"] = { str } }
	end ,
	["WPUB"] = function ( str ) -- Publishers official webpage
		return { ["publisher url"] = { str } }
	end ,
	["WXXX"] = function ( str ) -- Custom
		local t = vstruct.unpack ( "> field:z url:s" .. #str , str )
		t.url = string.match ( t.url  , "^%z*(.*)" ) or "" -- Strip any leading nulls
		return { [ t.url ] =  st }
	end ,	
	
	-- Music CD identifier
	["MCDI"] = function ( str )
		return { [ "cd toc"] = { str } }
	end ,
	
	-- ETCO -- Event timing codes -- TODO???? 
	-- MLLT -- Not applicable
	-- SYTC -- Synchronised tempo codes
	
	-- Unsynchronised lyrics/text transcription
	["USLT"] = function ( str )
		local t = vstruct.unpack ( "> encoding:u1 language:s3 description:z text:s" .. #str , str )
		t.text = string.match ( t.text  or "" , "^%z*(.*)" ) or "" -- Strip any leading nulls
		-- TODO: Can we do anything with language or description?
		return { [ "lyrics" ] = { t.text } }
	end ,
	
	-- SYLT -- Synchronised lyrics/text
	
	-- Comment
	["COMM"] = function ( str )
		local t = vstruct.unpack ( "> encoding:u1 language:s3 description:z text:s" .. #str , str )
		t.text = string.match ( t.text or "" , "^%z*(.*)" ) or "" -- Strip any leading nulls
		-- TODO: Can we do anything with language or description?
		return { [ "comment" ] = { t.text } }
	end ,
	
	-- RVA2 -- Relative volume adjustment (2)
	-- EQU2 -- Equalisation (2)
	-- RVRB -- Reverb
	
	-- Attached pictures
	--["APIC"] = function ( str )
		-- TODO: interpret pictures
	--end ,
	-- GEOB -- General encapsulated object

	-- PCNT -- Play counter
	-- POPM -- Popularimeter
	
	-- RBUF -- Recommended buffer size

	-- AENC -- Audio encryption

	-- LINK -- Linked information

	-- POSS -- Position synchronisation frame
	
	-- Terms of use frame
	["USER"] = function ( str )
		local t = vstruct.unpack ( "> encoding:u1 language:s3 description:z text:s" .. #str , str )
		t.text = string.match ( t.text or "" , "^%z*(.*)" ) or "" -- Strip any leading nulls
		-- TODO: Can we do anything with language or description?
		return { [ "terms of use" ] = { t.text } }
	end ,
	
	-- OWNE -- Ownership frame
	-- COMR -- Commericial frame
	
	-- ENCR -- Encryption method registration
	-- GRID -- Group identification registration

	-- PRIV -- Private frame
	-- SIGN -- Signature frame

	-- SEEK -- Seek frame
	
	-- ASPI -- Audio seek point index
	
	
	-- Older frames
	["TORY"] = function ( str ) -- Year
		return { [ "original release time" ] = readtextframe ( str ) }
	end ,
	["TYER"] = function ( str ) -- Year
		return { [ "date" ] = readtextframe ( str ) }
	end ,
}

local function readframe ( fd , header )
	local t = vstruct.unpack ( "> id:s4 safesyncsize:m4 statusflags:m1 formatflags:m1" , fd )
	if t.id == "\0\0\0\0" then -- padding
		return false , "padding"
	else
		--print("SAFESYNC" , vstruct.implode ( t.safesyncsize ) , unpack ( t.safesyncsize ) )
		t.framesize = vstruct.implode ( t.safesyncsize ) -- No desafesync?
		t.size = t.framesize
		--print("DESAFESYNC" , t.size , unpack ( vstruct.explode ( t.size ) ) )
		t.safesyncsize = nil
		if header.version == 4 then	
			-- %0abc0000 %0h00kmnp
			t.tagalterpreserv = t.statusflags [ 7 ]
			t.filealterpreserv = t.statusflags [ 6 ]
			t.readonly = t.statusflags [ 5 ]
			t.compressed = t.formatflags [  4 ]
			t.encrypted = t.formatflags [ 3 ]
			t.grouped = t.formatflags [ 7 ]
			t.unsynched = t.formatflags [ 2 ]
			t.hasdatalength = t.formatflags [ 1 ]
			if t.grouped then t.groupingbyte = fd:read ( 1 ) end
			if t.encrypted then t.encryption = fd:read ( 1 ) end
			if t.hasdatalength then t.datalength = fd:read ( 4 ) end
		elseif header.version <= 3 then
			t.tagalterpreserv = t.statusflags [ 8 ]
			t.filealterpreserv = t.statusflags [ 7 ]
			t.readonly = t.statusflags [ 6 ]
			t.compressed = t.formatflags [  8 ]
			t.encrypted = t.formatflags [ 7 ]
			t.grouped = t.formatflags [ 6 ]
			if t.compressed then
				t.size = t.size - 4
				t.datalength = fd:read ( 4 )
			end
			if t.encrypted then
				t.size = t.size - 1
				t.encryption = fd:read ( 1 ) 
			end
			if t.grouped then 
				t.size = t.size - 1
				t.groupingbyte = fd:read ( 1 ) 
			end
		end
		t.framecontents = fd:read ( t.size )
		t.contents = t.framecontents
		if t.unsynched then
			t.contents = t.contents:gsub ( "\255%z([224-\255])" ,  "\255%1" )
				:gsub ( "\255%z%z" ,  "\255\0" )
		end
		if t.encrypted then
			return false , "Encrypted frame, cannot decrypt"
		end
		if t.compressed then -- Frame compressed with zlib
			local ok , z = pcall ( require , "zlib" )
			if ok and z then
				t.contents = z.decompress ( t.contents )
			else
				return false , "Compressed frame and no zlib available"
			end
		end
		if framedecode [ t.id ] then
			return framedecode [ t.id ] ( t.contents )
		else -- We don't know of this frame type
			print ( "Unknown frame" , t.id , t.size , t.contents )
			return { }
		end
	end
end

function find ( fd )
	fd:seek ( "set" ) -- Look at start of file
	local h
	h = readheader ( fd )
	if h then return fd:seek ( "set" ) end
	fd:seek ( "end" , -10 )
	h = readheader ( fd )
	if h then 
		local offsetfooter = ( h.size + 20 ) -- Offset to start of footer from end of file
		fd:seek ( "end" , -offsetfooter) 
		h = readheader ( fd )
		if h and h.flags [ 5 ] then return fd:seek ( "end" , -offsetfooter ) end -- 4th flag (but its in reverse order) is if has footer
	end
end

function info ( fd , location , item )
	fd:seek ( "set" , location )
	local header = readheader ( fd )
	if header then
		item.tags = { }
		item.extra = { }
		local i = 0
		while i < ( header.size - 10) do
			local ok , err = readframe ( fd , header )
			if err == "padding" then
				break
			else
				ok = ok or { }
				--print ( table.recurseserialise ( ok ) )
				table.inherit ( item.tags , ok , true )
				i = fd:seek ( "cur" ) - header.firstframeoffset
			end
		end
		print ( table.recurseserialise ( item ) )	
		return item
	else
		return false
	end
end

function generatetag ( tags )

end

function edit ( )

end
