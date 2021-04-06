local ffi, bit = require('ffi'), require('bit')
local C = ffi.C

local File = {
	getBuffer = function(self) return self._bufferMode, self._bufferSize end,
	getFilename = function(self) return self._name end,
	getMode = function(self) return self._mode end,
	isEOF = function(self) return not self:isOpen() or C.feof(self._handle) ~= 0 or self:tell() == self:getSize() end,
	isOpen = function(self) return self._mode ~= 'c' and self._handle ~= nil end,
}

local fopen, getcwd, chdir, unlink, mkdir, rmdir
local BUFFERMODE, MODEMAP

function File:open(mode)
	if self._mode ~= 'c' then return false, "File " .. self._name .. " is already open" end
	if not MODEMAP[mode] then return false, "Invalid open mode for " .. self._name .. ": " .. mode end

	local handle = fopen(self._name, MODEMAP[mode])
	if handle == nil then return false, "Could not open " .. self._name .. " in mode " .. mode end

	if C.setvbuf(handle, nil, BUFFERMODE[self._bufferMode], self._bufferSize) ~= 0 then
		self._bufferMode, self._bufferSize = 'none', 0
	end

	self._handle, self._mode = ffi.gc(handle, C.fclose), mode
	return true
end

function File:close()
	if self._mode == 'c' then return false, "File is not open" end
	C.fclose(ffi.gc(self._handle, nil))
	self._handle, self._mode = nil, 'c'
	return true
end

function File:setBuffer(mode, size)
	local bufferMode = BUFFERMODE[mode]
	if not bufferMode then
		return false, "Invalid buffer mode " .. mode .. " (expected 'none', 'full', or 'line')"
	end

	if mode == 'line' or mode == 'full' then
		size = math.max(2, size or 2) -- Windows requires buffer to be at least 2 bytes
	else
		size = math.max(0, size or 0)
	end
	if self._mode == 'c' then
		self._bufferMode, self._bufferSize = mode, size
		return true
	end

	local success = C.setvbuf(self._handle, nil, bufferMode, size) == 0
	if success then
		self._bufferMode, self._bufferSize = mode, size
		return true
	end

	return false, "Could not set buffer mode"
end

function File:getSize()
	-- NOTE: The correct way to do this would be a stat() call, which requires a
	-- lot more (system-specific) code. This is a shortcut that requires the file
	-- to be readable.
	local mustOpen = not self:isOpen()
	if mustOpen and not self:open('r') then return 0 end

	local pos = mustOpen and 0 or self:tell()
	C.fseek(self._handle, 0, 2)
	local size = self:tell()
	if mustOpen then
		self:close()
	else
		self:seek(pos)
	end
	return size;
end

function File:read(containerOrBytes, bytes)
	if self._mode ~= 'r' then return nil, 0 end

	local container = bytes ~= nil and containerOrBytes or 'string'
	if container ~= 'string' and container ~= 'data' then
		error("Invalid container type: " .. container)
	end

	bytes = not bytes and containerOrBytes or 'all'
	bytes = bytes == 'all' and self:getSize() - self:tell() or math.min(self:getSize() - self:tell(), bytes)

	if bytes <= 0 then
		local data = container == 'string' and '' or love.data.newFileData('', self._name)
		return data, 0
	end

	local data = love.data.newByteData(bytes)
	local r = tonumber(C.fread(data:getFFIPointer(), 1, bytes, self._handle))

	local str = data:getString()
	data:release()
	data = container == 'data' and love.filesystem.newFileData(str, self._name) or str
	return data, r
end

function File:lines()
	if self._mode ~= 'r' then error("File is not opened for reading") end

	local BUFFERSIZE = 4096
	local buffer = ffi.new('unsigned char[?]', BUFFERSIZE)
	local bytesRead = tonumber(C.fread(buffer, 1, BUFFERSIZE, self._handle))

	local bufferPos = 0
	local offset = self:tell()
	return function()
		self:seek(offset)
		local line = {}
		while bytesRead > 0 do
			for i = bufferPos, bytesRead - 1 do
				if buffer[i] ~= 10 and buffer[i] ~= 13 then
					table.insert(line, string.char(buffer[i]))
				elseif buffer[i] == 10 then
					bufferPos = i + 1
					return table.concat(line)
				end
			end

			bytesRead = tonumber(C.fread(buffer, 1, BUFFERSIZE, self._handle))
			offset, bufferPos = offset + bytesRead, 0
		end
		return line[1] and table.concat(line) or nil
	end
end

function File:write(data, size)
	if self._mode ~= 'w' and self._mode ~= 'a' then
		return false, "File " .. self._name .. " not opened for writing"
	end
	local toWrite, writeSize
	if type(data) == 'string' then
		writeSize = (size == nil or size == 'all') and #data or size
		toWrite = data
	else
		writeSize = (size == nil or size == 'all') and data:getSize() or size
		toWrite = data:getFFIPointer()
	end
	if tonumber(C.fwrite(toWrite, 1, writeSize, self._handle)) ~= writeSize then
		return false, "Could not write data"
	end
	return true
end

function File:seek(pos)
	if self._handle == nil then return false end
	return C.fseek(self._handle, pos, 0) == 0
end

function File:tell()
	if self._handle == nil then return -1 end
	return tonumber(C.ftell(self._handle))
end

function File:flush()
	if self._handle == nil then return false, "File is not open" end
	return C.fflush(self._handle) == 0
end

function File:release()
	if self._mode ~= 'c' then
		self:close()
	end
	self._handle = nil
end

File.__index = File

-----------------------------------------------------------------------------

local nativefs = {}
local loveC = ffi.os == 'Windows' and ffi.load('love') or C

function nativefs.newFile(name)
	return setmetatable({
		_name = name,
		_mode = 'c',
		_handle = nil,
		_bufferSize = 0,
		_bufferMode = 'none'
	}, File)
end

function nativefs.newFileData(filepath)
	local f = nativefs.newFile(filepath)
	local ok, err = f:open('r')
	if not ok then return nil, err end

	local data, err = f:read('data', 'all')
	f:close()
	return data, err
end

function nativefs.mount(archive, mountPoint, appendToPath)
	return loveC.PHYSFS_mount(archive, mountPoint, appendToPath and 1 or 0) ~= 0
end

function nativefs.unmount(archive)
	return loveC.PHYSFS_unmount(archive) ~= 0
end

function nativefs.read(containerOrName, nameOrSize, sizeOrNil)
	local container, name, size
	if sizeOrNil then
		container, name, size = containerOrName, nameOrSize, sizeOrNil
	elseif not nameOrSize then
		container, name, size = 'string', containerOrName, 'all'
	else
		if type(nameOrSize) == 'number' or nameOrSize == 'all' then
			container, name, size = 'string', containerOrName, nameOrSize
		else
			container, name, size = containerOrName, nameOrSize, 'all'
		end
	end

	local file = nativefs.newFile(name)
	local ok, err = file:open('r')
	if not ok then return nil, err end

	local data, size = file:read(container, size)
	file:close()
	return data, size
end

local function writeFile(mode, name, data, size)
	local file = nativefs.newFile(name)
	local ok, err = file:open(mode)
	if not ok then return nil, err end

	ok, err = file:write(data, size or 'all')
	file:close()
	return ok, err
end

function nativefs.write(name, data, size)
	return writeFile('w', name, data, size)
end

function nativefs.append(name, data, size)
	return writeFile('a', name, data, size)
end

function nativefs.lines(name)
	local f = nativefs.newFile(name)
	local ok, err = f:open('r')
	if not ok then return nil, err end
	return f:lines()
end

function nativefs.load(name)
	local chunk, err = nativefs.read(name)
	if not chunk then return nil, err end
	return loadstring(chunk, name)
end

function nativefs.getWorkingDirectory()
	return getcwd()
end

function nativefs.setWorkingDirectory(path)
	if not chdir(path) then return false, "Could not set working directory" end
	return true
end

function nativefs.getDriveList()
	if ffi.os ~= 'Windows' then return { '/' } end
	local drives, bits = {}, C.GetLogicalDrives()
	for i = 0, 25 do
		if bit.band(bits, 2 ^ i) > 0 then
			table.insert(drives, string.char(65 + i) .. ':/')
		end
	end
	return drives
end

function nativefs.createDirectory(path)
	local current = ''
	for dir in path:gmatch('[^/\\]+') do
		current = (current == '' and current or current .. '/') .. dir
		local info = nativefs.getInfo(current, 'directory')
		if not info and not mkdir(current) then return false, "Could not create directory " .. current end
	end
	return true
end

function nativefs.remove(name)
	local info = nativefs.getInfo(name)
	if not info then return false, "Could not remove " .. name end
	if info.type == 'directory' then
		if not rmdir(name) then return false, "Could not remove directory " .. name end
		return true
	end
	if not unlink(name) then return false, "Could not remove file " .. name end
	return true
end

local function withTempMount(dir, fn)
	local mountPoint = loveC.PHYSFS_getMountPoint(dir)
	if mountPoint ~= nil then return fn(ffi.string(mountPoint)) end
	if not nativefs.mount(dir, '__nativefs__temp__') then return false, "Could not mount " .. dir end
	local a, b = fn('__nativefs__temp__')
	nativefs.unmount(dir)
	return a, b
end

function nativefs.getDirectoryItems(dir)
	local result, err = withTempMount(dir, function(mount)
		return love.filesystem.getDirectoryItems(mount)
	end)
	return result or {}
end

function nativefs.getDirectoryItemsInfo(path, filtertype)
	local result, err = withTempMount(path, function(mount)
		local items = {}
		local files = love.filesystem.getDirectoryItems(mount)
		for i = 1, #files do
			local filepath = string.format('%s/%s', mount, files[i])
			local info = love.filesystem.getInfo(filepath, filtertype)
			if info then
				info.name = files[i]
				table.insert(items, info)
			end
		end
		return items
	end)
	return result or {}
end

function nativefs.getInfo(path, filtertype)
	local dir = path:match("(.*[\\/]).*$") or './'
	local file = love.path.leaf(path)
	local result, err = withTempMount(dir, function(mount)
		local filepath = string.format('%s/%s', mount, file)
		return love.filesystem.getInfo(filepath, filtertype)
	end)
	return result or nil
end

-----------------------------------------------------------------------------

MODEMAP = { r = 'rb', w = 'wb', a = 'ab' }

ffi.cdef([[
	int PHYSFS_mount(const char* dir, const char* mountPoint, int appendToPath);
	int PHYSFS_unmount(const char* dir);
	const char* PHYSFS_getMountPoint(const char* dir);

	typedef struct FILE FILE;

	FILE* fopen(const char* path, const char* mode);
	size_t fread(void* ptr, size_t size, size_t nmemb, FILE* stream);
	size_t fwrite(const void* ptr, size_t size, size_t nmemb, FILE* stream);
	int fclose(FILE* stream);
	int fflush(FILE* stream);
	size_t fseek(FILE* stream, size_t offset, int whence);
	size_t ftell(FILE* stream);
	int setvbuf(FILE* stream, char* buffer, int mode, size_t size);
	int feof(FILE* stream);
]])

if ffi.os == 'Windows' then
	ffi.cdef([[
		int MultiByteToWideChar(unsigned int cp, uint32_t flags, const char* mb, int cmb, const wchar_t* wc, int cwc);
		int WideCharToMultiByte(unsigned int cp, uint32_t flags, const wchar_t* wc, int cwc, const char* mb,
		                        int cmb, const char* def, int* used);
		int GetLogicalDrives(void);
		int CreateDirectoryW(const wchar_t* path, void*);
		int _wchdir(const wchar_t* path);
		wchar_t* _wgetcwd(wchar_t* buffer, int maxlen);
		FILE* _wfopen(const wchar_t* path, const wchar_t* mode);
		int _wunlink(const wchar_t* path);
		int _wrmdir(const wchar_t* path);
	]])

	BUFFERMODE = { full = 0, line = 64, none = 4 }

	local function towidestring(str)
		local size = C.MultiByteToWideChar(65001, 0, str, #str, nil, 0)
		local buf = ffi.new('wchar_t[?]', size + 1)
		C.MultiByteToWideChar(65001, 0, str, #str, buf, size)
		return buf
	end

	local function toutf8string(wstr)
		local size = C.WideCharToMultiByte(65001, 0, wstr, -1, nil, 0, nil, nil)
		local buf = ffi.new('char[?]', size + 1)
		C.WideCharToMultiByte(65001, 0, wstr, -1, buf, size, nil, nil)
		return ffi.string(buf)
	end

	local MAX_PATH = 260
	local nameBuffer = ffi.new('wchar_t[?]', MAX_PATH + 1)

	fopen = function(path, mode) return C._wfopen(towidestring(path), towidestring(mode)) end
	getcwd = function() return toutf8string(C._wgetcwd(nameBuffer, MAX_PATH)) end
	chdir = function(path) return C._wchdir(towidestring(path)) == 0 end
	unlink = function(path) return C._wunlink(towidestring(path)) == 0 end
	mkdir = function(path) return C.CreateDirectoryW(towidestring(path), nil) ~= 0 end
	rmdir = function(path) return C._wrmdir(towidestring(path)) == 0 end
else
	BUFFERMODE = { full = 0, line = 1, none = 2 }

	ffi.cdef([[
		char* getcwd(char *buffer, int maxlen);
		int chdir(const char* path);
		int unlink(const char* path);
		int mkdir(const char* path, int mode);
		int rmdir(const char* path);
	]])

	local MAX_PATH = 4096
	local nameBuffer = ffi.new('char[?]', MAX_PATH)

	fopen = C.fopen
	unlink = function(path) return ffi.C.unlink(path) == 0 end
	chdir = function(path) return ffi.C.chdir(path) == 0 end
	mkdir = function(path) return ffi.C.mkdir(path, 0x1ed) == 0 end
	rmdir = function(path) return ffi.C.rmdir(path) == 0 end

	getcwd = function()
		local cwd = C.getcwd(nameBuffer, MAX_PATH)
		return cwd ~= nil and ffi.string(cwd) or nil
	end
end

return nativefs
