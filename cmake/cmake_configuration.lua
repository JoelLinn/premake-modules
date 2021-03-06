local p = premake
local tree = p.tree
local project = p.project
local config = p.config
local cmake = p.modules.cmake
cmake.config = {}
local m = cmake.config
m.elements = {}

-- Flags
function m.flags(cfg)
  local cmakeflags = '-Wall'
  local buildType = 'RelWithDebInfo'
  if cfg.buildcfg == 'Debug' then
    buildType = 'Debug'
  elseif cfg.buildcfg == 'Release' then
    buildType = 'Release'
  end
  if cfg.flags and #cfg.flags > 0 then
    for _, flag in ipairs(cfg.flags) do
      if flag == 'Symbols' then
        buildType = 'DebugFull'
      elseif flag == 'FatalWarnings' or flag == 'FatalCompileWarnings' then
        cmakeflags = cmakeflags..' -Werror'
      elseif flag == 'Unicode' then
        _p(1,'add_definitions(-DUNICODE -D_UNICODE)')
      end
    end    
    if (cfg.cppdialect == "C++14") then
      _p(1, 'set(CMAKE_CXX_STANDARD 14)')
    elseif (cfg.cppdialect == "C++17") then
      _p(1, 'set(CMAKE_CXX_STANDARD 17)')
    elseif (cfg.cppdialect == "C++20") then
      _p(1, 'set(CMAKE_CXX_STANDARD 20)')
    elseif (cfg.cppdialect == "C++latest") then
      _p(1, 'set(CMAKE_CXX_STANDARD 20)')
    end
  end
  if cfg.vectorextensions == 'AVX' then
    _p(1,'if((CMAKE_CXX_COMPILER_ID MATCHES "GNU") OR (CMAKE_CXX_COMPILER_ID MATCHES "Clang"))')
    _p(1,'  add_compile_options(-mavx)')
    _p(1,'elseif(CMAKE_CXX_COMPILER_ID MATCHES "Intel")')
    _p(1,'  add_compile_options(/QxAVX)')
    _p(1,'elseif(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")')
    _p(1,'  add_compile_options(/arch:AVX)')
    _p(1,'endif()')
  end
  _p(1, 'set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} %s")', cmakeflags)
  _p(1, 'set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} %s")', cmakeflags)
  _p(1, 'set(CMAKE_BUILD_TYPE %s)', buildType)
end

-- Add files
function m.files(cfg)
  if cfg.files then
    _p('')
    _p(1, "set(SRC ")
    for i,v in ipairs(cfg.files) do
      _p(2, project.getrelative(cfg.project, v))
    end
    _p(1, ")")
  end
end

-- Add executable / libs
function m.target(cfg)
  local kind = cfg.project.kind
  local targetname = cmake.targetname(cfg)
  if kind == 'StaticLib' then
    _p(1,'add_library( %s STATIC ${SRC})', targetname)
  elseif kind == 'SharedLib' then
    _p(1,'add_library( %s SHARED ${SRC})', targetname)
  elseif kind == 'ConsoleApp' or kind == 'WindowedApp' then
    _p(1,'add_executable( %s ${SRC})', targetname)
  else

  end
end

-- Set targets output properties
function m.targetprops(cfg)
  local targetname = cmake.targetname(cfg)
  local filename = cfg.filename
  if cfg.targetname then filename = cfg.targetname end
  if cfg.targetdir and targetname and filename then
    _p(1,'set_target_properties( %s ', targetname)
    _p(2,'PROPERTIES')
    _p(2,'ARCHIVE_OUTPUT_DIRECTORY "%s"', cfg.targetdir)
    _p(2,'LIBRARY_OUTPUT_DIRECTORY "%s"', cfg.targetdir)
    _p(2,'RUNTIME_OUTPUT_DIRECTORY "%s"', cfg.targetdir)
    _p(2,'OUTPUT_NAME  "%s"', filename)
    _p(1,')')
  end
end

-- Generate Defines
function m.defines(cfg)
  if cfg.defines and #cfg.defines then
    local targetname = cmake.targetname(cfg)
    _p('')
    _p(1, 'target_compile_definitions( %s PUBLIC', targetname)    
    for _, define in ipairs(cfg.defines) do
      _p(2, '-D%s', define)
    end
    _p(1,')')
  end
end

-- Set lib directories
function m.libdirs(cfg)
  if #cfg.libdirs > 0 then
    _p('')
    _p(1,'set(LIB_DIRS')
    local libdirs = project.getrelative(cfg.project, cfg.libdirs)
    for _, libpath in ipairs(libdirs) do
      _p(2, libpath)
    end
    _p(1,')')
    _p(1,'link_directories(${LIB_DIRS})')
  end
end

-- Generate include directories
function m.includedirs(cfg)
  if cfg.includedirs and #cfg.includedirs > 0 then
    _p('')
    _p(1,'set(INCLUDE_DIRS ')
    for _, includedir in ipairs(cfg.includedirs) do
      local dirpath = project.getrelative(cfg.project, includedir)
      _p(2, dirpath)
    end
    _p(1,')')
    local targetname = cmake.targetname(cfg)
    _p(1,'target_include_directories(%s PRIVATE ${INCLUDE_DIRS})', targetname)
  end
end

-- Set System Link libs
function m.system_links(cfg)
  local links = config.getlinks(cfg, "system", "fullpath")
  if links and #links>0 then
    _p('')
    _p(1, 'set(SYSTEM_LIBS ')
    for _, libname in ipairs(links) do
      _p(2, libname)
    end
    _p(1, ')')
    local targetname = cmake.targetname(cfg)
    _p(1, 'target_link_libraries(%s PRIVATE ${SYSTEM_LIBS})', targetname)
  end
end

-- Set Sibling Link libs
function m.sibling_links(cfg)
  local links = config.getlinks(cfg, "sibling", "basename")
  if links and #links>0 then
    _p('')
    _p(1, 'set(SIBLING_LIBS ')
    for _, libname in ipairs(links) do
      -- TODO FIXME sub(4) on Linux ????
      _p(2, libname:sub(0)..'_'..cmake.cfgname(cfg))
    end
    _p(1, ')')
    local targetname = cmake.targetname(cfg)
    _p(1, 'target_link_libraries(%s PRIVATE ${SIBLING_LIBS})', targetname)
  end
end

-- Generate Call array
function m.elements.generate(cfg)
  return {
    m.flags,
    m.libdirs,
    m.files,
    m.target,
    m.targetprops,
    m.defines,
    m.includedirs,
    m.system_links,
    m.sibling_links,
  }
end

function m.generate(prj, cfg)
  if prj.kind ~= 'Utility' then
	  p.callArray(m.elements.generate, cfg)
  end
end
