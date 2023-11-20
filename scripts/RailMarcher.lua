--[[ RailMarcher.lua © Penguin_Spy 2023
  Utilities for finding catenary poles alongside rails
]]

local RailMarcher = {}

-- store these to reduce table dereferences
local STRAIGHT = defines.rail_connection_direction.straight
local LEFT = defines.rail_connection_direction.left
local RIGHT = defines.rail_connection_direction.right
local FRONT = defines.rail_direction.front
local BACK = defines.rail_direction.back

-- directions the straight rails use
local VERTICAL = defines.direction.north   -- front is up, back is down
local HORIZONTAL = defines.direction.east  -- front is right, back is left


-- diagonal rails
-- 1 & 3 go  up  when getting the "front" "straight" rail
local NORTHEAST = defines.direction.northeast
local SOUTHEAST = defines.direction.southeast
-- 5 & 7 go down when getting the "front" "straight" rail
local SOUTHWEST = defines.direction.southwest
local NORTHWEST = defines.direction.northwest

local pole_names = {"oe-catenary-pole", "oe-transformer"}

-- joins arrays. modifies `a` in place
---@param a table
---@param b table
local function join(a, b)
  for _, v in pairs(b) do
    a[#a+1] = v
  end
end

-- shallow copies an array. returns the new array
---@generic T: table
---@param t T
---@return T
local function copy(t)
  local c = {}
  for k, v in pairs(t) do
    c[k] = v
  end
  return c
end


-- determines if a `straight-rail` is orthogonal or diagonal <br>
-- result is not valid for `curved-rail`!
---@param direction defines.direction
---@return boolean
---@nodiscard
local function is_orthogonal(direction)
  return direction == HORIZONTAL or direction == VERTICAL
end


-- gets the next rail in the given direction (`FRONT`/`BACK`) & connection direction (`STRAIGHT`/`LEFT`/`RIGHT`) <br>
-- handles diagonal/curved rails (diagonal "front" is always upwards)
---@param rail LuaEntity
---@param direction defines.rail_direction
---@param connection defines.rail_connection_direction
---@return LuaEntity?
---@nodiscard
local function get_next_rail(rail, direction, connection)
  local entity_direction = rail.direction

  -- straight/diagonal rails
  if rail.type == "straight-rail" then
    if entity_direction == SOUTHWEST or entity_direction == NORTHWEST then
      -- inverts direction so diagonal rails are consistent
      return rail.get_connected_rail{rail_direction = direction == FRONT and BACK or FRONT, rail_connection_direction = connection}
    end
    -- vertical/horizontal or normal diagonal directions
    return rail.get_connected_rail{rail_direction = direction, rail_connection_direction = connection}

    -- curved rails
  else
    return rail.get_connected_rail{rail_direction = direction, rail_connection_direction = connection}
  end
end
-- debug
RailMarcher.get_next_rail = get_next_rail


-- finds poles next to a single rail <br>
-- if `single` is true, return values are `LuaEntity`, else it's `LuaEntity[]`
-- if `rail` is a curved-rail, `back_poles` is the pole on the diagonal end, else it is nil
-- TODO: don't return poles that aren't facing the rail we're checking (for the inside of the corner of curved/straight switch thingy)
---@param rail LuaEntity
---@param color Color
---@param single boolean
---@param skip_front boolean?  debug
---@param skip_back boolean?   debug
---@return LuaEntity|LuaEntity[]|nil poles
---@return LuaEntity|LuaEntity[]|nil back_poles
---@nodiscard
local function find_adjacent_poles(rail, color, single, skip_front, skip_back)
  if rail.type == "straight-rail" then
    local position = rail.position
    local direction = rail.direction

    -- adjust search radius to actual center of diagonal rails
    if direction == SOUTHWEST then
      position.x = position.x - 0.5
      position.y = position.y + 0.5
    elseif direction == NORTHWEST then
      position.x = position.x - 0.5
      position.y = position.y - 0.5
    elseif direction == SOUTHEAST then
      position.x = position.x + 0.5
      position.y = position.y + 0.5
    elseif direction == NORTHEAST then
      position.x = position.x + 0.5
      position.y = position.y - 0.5
    end

    local radius = is_orthogonal(direction) and 2 or 1.5

    rendering.draw_circle{color = color, width = 2, filled = false, target = position, surface = rail.surface, radius = radius, only_in_alt_mode = true}
    -- this is easier then trying to convince sumneko.lua that back_poles won't be nil for curved rails
    if single then
      return rail.surface.find_entities_filtered{position = position, radius = radius, name = pole_names, limit = 1}[1], nil
    else
      return rail.surface.find_entities_filtered{position = position, radius = radius, name = pole_names}, nil
    end

    --
  elseif rail.type == "curved-rail" then
    local front_position, back_position = rail.position, rail.position
    local direction = rail.direction

    -- yup.
    if direction == defines.direction.north then
      front_position.x = front_position.x + 1
      front_position.y = front_position.y + 3.5
      back_position.x = back_position.x - 1.5
      back_position.y = back_position.y - 2.5
    elseif direction == defines.direction.northeast then
      front_position.x = front_position.x - 1
      front_position.y = front_position.y + 3.5
      back_position.x = back_position.x + 1.5
      back_position.y = back_position.y - 2.5
    elseif direction == defines.direction.east then
      front_position.x = front_position.x - 3.5
      front_position.y = front_position.y + 1
      back_position.x = back_position.x + 2.5
      back_position.y = back_position.y - 1.5
    elseif direction == defines.direction.southeast then
      front_position.x = front_position.x - 3.5
      front_position.y = front_position.y - 1
      back_position.x = back_position.x + 2.5
      back_position.y = back_position.y + 1.5
    elseif direction == defines.direction.south then
      front_position.x = front_position.x - 1
      front_position.y = front_position.y - 3.5
      back_position.x = back_position.x + 1.5
      back_position.y = back_position.y + 2.5
    elseif direction == defines.direction.southwest then
      front_position.x = front_position.x + 1
      front_position.y = front_position.y - 3.5
      back_position.x = back_position.x - 1.5
      back_position.y = back_position.y + 2.5
    elseif direction == defines.direction.west then
      front_position.x = front_position.x + 3.5
      front_position.y = front_position.y - 1
      back_position.x = back_position.x - 2.5
      back_position.y = back_position.y + 1.5
    elseif direction == defines.direction.northwest then
      front_position.x = front_position.x + 3.5
      front_position.y = front_position.y + 1
      back_position.x = back_position.x - 2.5
      back_position.y = back_position.y - 1.5
    else
      error("rail direction invalid " .. direction)
    end

    if not skip_front then
      rendering.draw_circle{color = color, width = 2, filled = false, target = front_position, radius = 1.5, surface = rail.surface, only_in_alt_mode = true}
    end
    if not skip_back then
      rendering.draw_circle{color = color, width = 2, filled = false, target = back_position, radius = 1.425, surface = rail.surface, only_in_alt_mode = true}
    end

    local front_pole, back_pole
    if single then
      front_pole = rail.surface.find_entities_filtered{position = front_position, radius = 1.5, name = pole_names, limit = 1}[1]
      back_pole = rail.surface.find_entities_filtered{position = back_position, radius = 1.425, name = pole_names, limit = 1}[1]
    else
      front_pole = rail.surface.find_entities_filtered{position = front_position, radius = 1.5, name = pole_names}
      back_pole = rail.surface.find_entities_filtered{position = back_position, radius = 1.425, name = pole_names}
    end

    return front_pole, back_pole
  end
  error("cannot find ajacent poles: '" .. rail.name .. "' is not a straight-rail or curved-rail")
end
RailMarcher.find_adjacent_poles = find_adjacent_poles


local insert = table.insert

---@param rail LuaEntity                      the rail to march from
---@param direction defines.rail_direction    the direction to march in
---@param path integer[]                      the unit_numbers of the rails leading up to this rail
---@param distance integer                    the remaining distance to travel
---@param on_pole fun(other_pole: LuaEntity, path: integer[], distance: integer, this_pole: LuaEntity): quit: boolean? the callback to run when a pole is found
---@param this_pole LuaEntity                 the original pole
---@param ignore_pole LuaEntity?              a pole to ignore for calling on_pole
---@return boolean? quit
local function march_rail(rail, direction, path, distance, on_pole, this_pole, ignore_pole)
  log(serpent.line{rail, direction, path, distance, on_pole and "on_pole"})
  local rail_lut = global.pole_powering_rail

  -- check LEFT, STRAIGHT, and RIGHT rails for poles
  --  when a pole is found (don't march past that rail)
  --  call the on_pole callback

  local rail_into_curve_is_orthogonal
  if rail.type == "straight-rail" then
    rail_into_curve_is_orthogonal = is_orthogonal(rail.direction)
  else  -- rail.type == "curved-rail"
    rail_into_curve_is_orthogonal = direction == FRONT
  end

  -- LEFT & RIGHT are curves
  --  check close point for poles
  --  if enough distance left, check far point for poles
  local left_rail = get_next_rail(rail, direction, LEFT)  --[[@as LuaEntity|nil|false]]
  local left_path, left_direction  --[[@type nil, nil]]
  if left_rail then
    local rail_id = left_rail.unit_number
    left_path = copy(path)
    insert(left_path, rail_id)

    -- adjust direction for curved/diagonal shenanigans
    if direction == FRONT and rail_into_curve_is_orthogonal then
      left_direction = BACK
    elseif direction == BACK and not rail_into_curve_is_orthogonal then
      left_direction = FRONT
    else
      left_direction = direction
    end

    -- check for poles
    local f, b = find_adjacent_poles(left_rail, {0, 1, 1}, true, not rail_into_curve_is_orthogonal and distance <= 3, rail_into_curve_is_orthogonal and distance <= 3)
    if not rail_into_curve_is_orthogonal then
      f, b = b, f  -- swap front & back if coming from diagonal rail
    end
    if f then
      if f ~= ignore_pole then
        left_rail = false  -- don't march past this rail
        local quit = on_pole(f, left_path, distance, this_pole)
        if quit then return quit end
      end
    end
    if b and distance > 3 then
      if b ~= ignore_pole then
        left_rail = false  -- don't march past this rail
        local quit = on_pole(b, left_path, distance - 3, this_pole)
        if quit then return quit end
      end
    end
  end

  local right_rail = get_next_rail(rail, direction, RIGHT)  --[[@as LuaEntity|nil|false]]
  local right_path, right_direction  --[[@type nil, nil]]
  if right_rail then
    local rail_id = right_rail.unit_number
    right_path = copy(path)
    insert(right_path, rail_id)

    -- adjust direction for curved/diagonal shenanigans
    if direction == FRONT and rail_into_curve_is_orthogonal then
      right_direction = BACK
    elseif direction == BACK and not rail_into_curve_is_orthogonal then
      right_direction = FRONT
    else
      right_direction = direction
    end

    -- check for poles
    local f, b = find_adjacent_poles(right_rail, {1, 1, 0}, true, not rail_into_curve_is_orthogonal and distance <= 3, rail_into_curve_is_orthogonal and distance <= 3)
    if not rail_into_curve_is_orthogonal then
      f, b = b, f  -- swap front & back if coming from diagonal rail
    end
    if f then
      if f ~= ignore_pole then
        right_rail = false  -- don't march past this rail
        local quit = on_pole(f, right_path, distance, this_pole)
        if quit then return quit end
      end
    end
    if b and distance > 3 then
      if b ~= ignore_pole then
        right_rail = false  -- don't march past this rail
        local quit = on_pole(b, right_path, distance - 3, this_pole)
        if quit then return quit end
      end
    end
  end

  -- STRAIGHT is a straight rail
  local straight_rail = get_next_rail(rail, direction, STRAIGHT)  --[[@as LuaEntity|nil|false]]
  if straight_rail then
    local rail_id = straight_rail.unit_number
    insert(path, rail_id)

    if rail.type == "curved-rail" then
      -- need to swap direction depending on the rotation of `rail` (the curved rail we're coming from)
      if direction == FRONT and rail.direction <= 3 then
        direction = BACK
      elseif rail.direction <= 2 or rail.direction == 7 then  -- direction == BACK
        direction = FRONT
      end
    end

    -- check for poles
    local p = find_adjacent_poles(straight_rail, {0, 1, 0}, true)
    if p then
      if p ~= ignore_pole then
        straight_rail = false  -- don't march past this rail
        local quit = on_pole(p, path, distance, this_pole)
        if quit then return quit end
      end
    end
  end

  -- call march_rail recursively on the found LEFT, STRAIGHT, and RIGHT rails (if enough distance & it didn't have a pole)
  --  pass a reduced distance (-1 for STRAIGHT, -4 for curved rails (from cost of placing them))
  --  flip direction param if necessary (entering/leaving curve, ~~diagonal shenanegans?~~)
  --  pass a copy of the path array to the LEFT/RIGHT marches, straight gets the one we got (works as long as we run straight last i think -- MAKE SURE TO TEST THIS)
  --  pass the on_pole callback, this_pole, and ignore_pole

  if straight_rail and distance > 1 then
    log("  marching straight")
    local quit = march_rail(straight_rail, direction, path, distance - 1, on_pole, this_pole, ignore_pole)
    if quit then return quit end
  end

  if left_rail and distance > 4 then  -- if a rail was found, the dir and path will not be nil
    log("  marching left")
    local quit = march_rail(left_rail, left_direction  --[[@as(integer)]], left_path  --[[@as(integer[])]], distance - 4, on_pole, this_pole, ignore_pole)
    if quit then return quit end
  end
  if right_rail and distance > 4 then
    log("  marching right")
    local quit = march_rail(right_rail, right_direction  --[[@as(integer)]], right_path  --[[@as(integer[])]], distance - 4, on_pole, this_pole, ignore_pole)
    if quit then return quit end
  end
end


--- march from the given rails, for connecting a new pole to other poles
--- TODO: don't march the same direction twice (from straight-rail and curved-rail)
---@param rails LuaEntity[]                   the rails to march from
---@param on_pole fun(other_pole: LuaEntity, path: integer[], distance: integer, this_pole: LuaEntity): quit: boolean? the callback to run when a pole is found
---@param this_pole LuaEntity                 the original pole
---@param ignore_pole LuaEntity?              a pole to ignore for calling on_pole
---@return boolean? quit                      true if the placement is invalid
function RailMarcher.march_to_connect(rails, on_pole, this_pole, ignore_pole)
  for _, rail in pairs(rails) do
    if rail.type == "straight-rail" then
      -- find_adjacent_poles, return true if other poles
      local poles = find_adjacent_poles(rail, {1, 0, 0}, false)
      util.remove_from_list(poles, this_pole)
      if #poles > 0 then
        log("pole too close")
        return true
      end
      -- march_rail(rail, FRONT) and march_rail(rail, BACK), returning true if either return quit=true
      log("march_rail for straight rail")
      if march_rail(rail, FRONT, {}, 7, on_pole, this_pole, ignore_pole)
          or march_rail(rail, BACK, {}, 7, on_pole, this_pole, ignore_pole) then
        log("pole too close during marching")
        return true
      end
      -- if placement succeded, mark adjacent rail as powered by this pole
      global.pole_powering_rail[rail.unit_number] = this_pole

      --
    else  -- rail.type == "curved-rail"
      local f, b = find_adjacent_poles(rail, {1, 0, 0}, false)

      -- check which end we're on, return true if other poles on the end we're on
      local on_orthogonal_end = util.remove_from_list(f, this_pole)
      if on_orthogonal_end then  -- on "FRONT" end of curved-rail
        -- if there were other poles on this end, block placement
        if #f > 0 then
          log("pole too close")
          return true
        end
        -- march in the "FRONT" direction, and if there are poles there, block placement
        log("march_rail FRONT for curved rail")
        if march_rail(rail, FRONT, {}, 7, on_pole, this_pole, ignore_pole) then
          log("pole too close during marching")
          return true
        end
        -- if there's a back pole, connect to it & don't march
        if b and b[1] and b[1] ~= ignore_pole then
          on_pole(b[1], {}, 4, this_pole)
        else
          -- march in the "BACK" direction (with less distance), no blocking because anything on that end is far enough away
          log("march_rail BACK for curved rail")
          march_rail(rail, BACK, {}, 3, on_pole, this_pole, ignore_pole)
        end

        --
      else  -- on "BACK" end of curved-rail
        -- if there were other poles on this end, block placement
        util.remove_from_list(b, this_pole)
        if #b > 0 then
          log("pole too close")
          return true
        end
        -- march in the "BACK" direction, and if there are poles there, block placement
        log("march_rail BACK for curved rail")
        if march_rail(rail, BACK, {}, 7, on_pole, this_pole, ignore_pole) then
          log("pole too close during marching")
          return true
        end
        -- if there's a front pole, connect to it & don't march
        if f and f[1] and f[1] ~= ignore_pole then
          on_pole(f[1], {}, 4, this_pole)
        else
          -- march in the "FRONT" direction (with less distance), no blocking because anything on that end is far enough away
          log("march_rail FRONT for curved rail")
          march_rail(rail, FRONT, {}, 3, on_pole, this_pole, ignore_pole)
        end
      end

      -- if placement succeded, mark adjacent rail as powered by this pole
      global.pole_powering_rail[rail.unit_number] = this_pole
    end
  end

  return false
end


return RailMarcher
