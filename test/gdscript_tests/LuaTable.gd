extends RefCounted

var lua_state


func _init():
	lua_state = LuaState.new()
	lua_state.open_libraries()


func test_metatable_tostring() -> bool:
	var table = lua_state.do_string("""
		function __tostring(self)
			return "hello " .. (self.name or "world")
		end
		return setmetatable({}, { __tostring = __tostring })
	""")
	assert(not table is LuaError, "Lua code failed: %s" % table)
	assert(str(table) == "hello world", "__tostring was not called")
	table.set("name", "gilzoide")
	assert(str(table) == "hello gilzoide", "__tostring was not called")
	return true


func test_get_value() -> bool:
	var table = lua_state.do_string("""
		local t = { 1, 2, 3, 4,
			hello = "world",
			some_vector2 = Vector2(),

		}
		t[t] = "self"
		return t
	""")
	assert(table is LuaTable)
	for i in range(1, table.length() + 1):
		assert(table.get(i) == i)
	assert(table.get("hello") == "world")
	assert(table.get("invalid") == null)
	assert(table.get("invalid_with_defaul", "default") == "default")
	assert(table.get("some_vector2") == Vector2())
	assert(table.get(table) == "self")
	return true


func test_rawget() -> bool:
	var table = lua_state.do_string("""
		local t = { value = 'value' }
		return setmetatable({}, { __index = t })
	""")
	assert(table.get("value") == "value")
	assert(table.rawget("value") == null)
	return true


func test_rawset() -> bool:
	var table = lua_state.do_string("""
		local t = {}
		return setmetatable({}, { __newindex = t })
	""")
	table.set("value", "value")
	assert(table.get("value") == null)
	table.rawset("value", "value")
	assert(table.get("value") == "value")
	return true


func test_set_value() -> bool:
	var table = lua_state.create_table()
	table.set(1, 1)
	table.set(2, 2)
	table.set(3, 3)
	table.set(4, 4)
	assert(table.length() == 4)
	return true


func test_property() -> bool:
	var table = lua_state.create_table()
	table.value = "value"
	assert(table.value == "value")
	return true


func test_clear() -> bool:
	var table = lua_state.create_table()
	table.set(1, 1)
	table.set(2, 2)
	table.set(3, 3)
	table.set(4, 4)
	table.clear()
	assert(table.length() == 0)
	for k in table:
		assert(false, "Cleared table should have no key/value pair")
	return true


func test_unpack_same_state() -> bool:
	var table = lua_state.create_table()
	lua_state.globals.set("t", table)
	var t_type = lua_state.do_string("return type(t)")
	assert(t_type == "table", "Table should be unpacked from Variant when passed to its LuaState")
	return true


func test_dont_unpack_other_state() -> bool:
	var table = lua_state.create_table()
	var other_state = LuaState.new()
	other_state.open_libraries()
	other_state.globals.set("t", table)
	var t_type = other_state.do_string("return type(t)")
	assert(t_type == "userdata", "Table should remain as Variant when passed to another LuaState")
	return true


func test_setgetmetatable() -> bool:
	var table = lua_state.create_table()
	assert(table.get_metatable() == null)
	assert(table.get_metatable() == lua_state.globals.getmetatable.invoke(table))

	var metatable = lua_state.create_table()
	table.set_metatable(metatable)
	assert(table.get_metatable() == metatable)
	assert(table.get_metatable() == lua_state.globals.getmetatable.invoke(table))

	table.set_metatable(null)
	assert(table.get_metatable() == null)
	assert(table.get_metatable() == lua_state.globals.getmetatable.invoke(table))
	return true


func test_to_dictionary_pairs() -> bool:
	var table = lua_state.do_string("""
		local function iterate_index_then_self(t)
			-- iteration over `t` metatable's __index table, if there's any
			local mt = getmetatable(t)
			if mt and type(mt.__index) == "table" then
				for k, v in pairs(mt.__index) do
					coroutine.yield(k, v)
				end
			end

			-- now iterate over `t` normally
			for k, v in next, t, nil do
				coroutine.yield(k, v)
			end
		end

		local t = {
			key1 = 1,
			key2 = 2,
		}
		setmetatable(t, {
			-- Here's an example "__index" table
			__index = {
				meta_key1 = 1,
				meta_key2 = 2,
			},
			-- And here's the "__pairs" metamethod
			__pairs = function(t)
				return coroutine.wrap(iterate_index_then_self), t, nil
			end,
		})
		return t
	""")

	assert(table.to_dictionary() == {
		key1 = 1,
		key2 = 2,
		meta_key1 = 1,
		meta_key2 = 2,
	})
	
	return true
