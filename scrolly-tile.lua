SCREEN_W = 160
SCREEN_H = 120

TILE_W = 10
TILE_H = 10
TILE_SOLID = 1 << 7
TILE_WATER = 1 << 6

-- Bitmask for keeping track of adjacent tiles
-- in a single uint8_t
TILE_LEFT =        1 << 7
TILE_RIGHT =       1 << 6
TILE_BELOW =       1 << 5
TILE_ABOVE =       1 << 4
TILE_ABOVE_LEFT =  1 << 3
TILE_ABOVE_RIGHT = 1 << 2
TILE_BELOW_LEFT =  1 << 1
TILE_BELOW_RIGHT = 1 << 0

PLAYER_W = 2
PLAYER_H = 4

TILES_X = 16
TILES_Y = 15

--[[
PLAYER_TOP = (player_position.y)
PLAYER_BOTTOM = (player_position.y + PLAYER_H)
PLAYER_RIGHT = (player_position.x + PLAYER_W)
PLAYER_LEFT = (player_position.x)
]]

RANDOM_TYPE_HRNG = 0
RANDOM_TYPE_PRNG = 1

PASSAGE_COUNT = 5

-- Number of times a player can jump sequentially
-- including mid-air jumps and the initial ground
-- or wall jump
MAX_JUMP = 3

current_random_source = RANDOM_TYPE_PRNG
current_random_seed = 0x64063701

-- All the art is rainbow fun time, so we don't need
-- much data about each tile.
-- Rounded corners are also procedural depending upon
-- tile proximity.
-- The screen allows for 16x12 10x10 tiles, but we
-- use an extra 3 vertically:
-- +1 - because an offset row means we can see 13 rows total
-- +2 - because tile features need an adjacent row to generate from
-- IE: when our screen is shifted down 5px you can see 13
-- rows and both the top and bottom visible row are next to the
-- additional two invisible rows which govern how corners are rounded.
--tiles[16 * 15] = { 0 }
tiles = {}

current_row = 0

--Timer state_update
tile_offset = Point(0, 0)


player_position = Vec2(80.0, SCREEN_H - PLAYER_H)
player_velocity = Vec2(0.0, 0.0)
jump_velocity = Vec2(0.0, -2.0)
player_jump_count = 0
player_progress = 0
player_on_floor = false
enum_player_state = {
  ground = 0,
  near_wall_left = 1,
  wall_left = 2,
  near_wall_right = 3,
  wall_right = 4,
  air = 5
}
player_state = enum_player_state.ground

last_passage_width = 0

water_level = 0

-- Used for tracking where the engine has linked a finished passage
-- back to those still active.
linked_passage_mask = 0

--passages[PASSAGE_COUNT] = {0}
passages = {}

-- Keep track of game state
enum_state = {
  menu = 0,
  play = 1,
  dead = 2
}

game_state = enum_state.menu

-- using tile_callback = uint8_t (*)(uint8_t tile, uint8_t x, uint8_t y, void *args);

prng_lfsr = 0
prng_tap = 0x74b8

function get_random_number()
  if current_random_source == RANDOM_TYPE_HRNG then
    return 0 --blit::random
  elseif current_random_source == RANDOM_TYPE_PRNG then
    local lsb = prng_lfsr & 1
    prng_lfsr = prng_lfsr >> 1

    if lsb ~= 0 then
      prng_lfsr = prng_lfsr ~ prng_tap
    end

    return prng_lfsr
  end
end

function for_each_tile(callback, args)
  for y = 0, TILES_Y - 1 do
    for x = 0, TILES_X - 1 do
      local index = (y * TILES_X) + x
      tiles[index] = callback(tiles[index], x, y, args)
    end
  end
end

function get_tile_at(x, y)
  -- Get the tile at a given x/y grid coordinate
  if x < 0 then return TILE_SOLID end
  if x > 15 then return TILE_SOLID end
  if y > TILES_Y then return 0 end
  if y < 0 then return TILE_SOLID end
  local index = (y * TILES_X) + x
  return tiles[index] or 0
end

function get_adjacent_tile_solid_flags(x, y)
  -- TODO: avoid calls to get_tile_at and use offsets to find
  -- adjacent tiles more efficiently.
  local feature_map = 0
  if get_tile_at(x - 1, y) & TILE_SOLID ~= 0 then feature_map = feature_map | TILE_LEFT end
  if get_tile_at(x + 1, y) & TILE_SOLID ~= 0 then feature_map = feature_map | TILE_RIGHT end
  if get_tile_at(x, y - 1) & TILE_SOLID ~= 0 then feature_map = feature_map | TILE_ABOVE end
  if get_tile_at(x, y + 1) & TILE_SOLID ~= 0 then feature_map = feature_map | TILE_BELOW end

  if get_tile_at(x - 1, y - 1) & TILE_SOLID ~= 0 then feature_map = feature_map | TILE_ABOVE_LEFT end
  if get_tile_at(x + 1, y - 1) & TILE_SOLID ~= 0 then feature_map = feature_map | TILE_ABOVE_RIGHT end
  if get_tile_at(x - 1, y + 1) & TILE_SOLID ~= 0 then feature_map = feature_map | TILE_BELOW_LEFT end
  if get_tile_at(x + 1, y + 1) & TILE_SOLID ~= 0 then feature_map = feature_map | TILE_BELOW_RIGHT end
  return feature_map
end

function render_tile(tile, x, y, args)
  -- Rendering tiles is pretty simple and involves drawing rectangles
  -- in the right places.
  -- But a large amount of this function is given over to rounding
  -- corners depending upon the content of neighbouring tiles.
  -- This could probably be rewritten to use a lookup table?
  local offset = args

  local tile_x = (x * TILE_W) + offset.x
  local tile_y = (y * TILE_H) + offset.y

  local feature_map = get_adjacent_tile_solid_flags(x, y)

  local round_tl = (feature_map & (TILE_ABOVE_LEFT | TILE_ABOVE | TILE_LEFT)) == 0
  local round_tr = (feature_map & (TILE_ABOVE_RIGHT | TILE_ABOVE | TILE_RIGHT)) == 0
  local round_bl = (feature_map & (TILE_BELOW_LEFT | TILE_BELOW | TILE_LEFT)) == 0
  local round_br = (feature_map & (TILE_BELOW_RIGHT | TILE_BELOW | TILE_RIGHT)) == 0

  local color_base = blit.hsv_to_rgba(((120 - tile_y) + 110.0) / 120.0, 0.5, 0.8)
  blit.pen(color_base)

  if tile & TILE_SOLID ~= 0 then
    -- Draw tiles without anti-aliasing to save code bloat
    -- Uses the rounded corner flags to miss a pixel for a
    -- basic rounded corner effect.

    if not round_tl and not round_tr and not round_bl and not round_br then
      -- it's a solid rectangle
      blit.rectangle(Rect(tile_x, tile_y, TILE_W, TILE_H))
    else
      -- top row
      local start_x = 0
      local end_x = TILE_W
      if round_tl then start_x = 1 end
      if round_tr then end_x = end_x - 1 end

      blit.rectangle(Rect(tile_x + start_x, tile_y, end_x - start_x, 1)) -- h_span?

      -- bottom row
      start_x = 0
      end_x = TILE_W
      if round_bl then start_x = 1 end
      if round_br then end_x = end_x - 1 end

      blit.rectangle(Rect(tile_x + start_x, tile_y + TILE_H - 1, end_x - start_x, 1))

      -- rest of the tile
      blit.rectangle(Rect(tile_x, tile_y + 1, TILE_W, TILE_H - 2))
    end
  else
    if feature_map & TILE_ABOVE ~= 0 then
      -- Draw the top left/right rounded inside corners
      -- for an empty tile.
      if feature_map & TILE_LEFT ~= 0 then
        blit.pixel(Point(tile_x, tile_y))
      end
      if feature_map & TILE_RIGHT ~= 0 then
        blit.pixel(Point(tile_x + TILE_W - 1, tile_y))
      end
    end
    if feature_map & TILE_BELOW ~= 0 then
      -- If we have a tile directly to the left and right
      -- of this one then it's a little pocket we can fill with water!
      -- TODO: Make this not look rubbish
      if feature_map & TILE_LEFT ~= 0 and feature_map & TILE_RIGHT ~= 0 then
        blit.pen(Pen(200, 200, 255, 128))
        blit.rectangle(Rect(tile_x, tile_y + (TILE_H / 2), TILE_W, TILE_H / 2))
        blit.pen(color_base)
      end
      -- Draw the bottom left/right rounded inside corners
      -- for an empty tile.
      if feature_map & TILE_LEFT ~= 0 then
        blit.pixel(Point(tile_x, tile_y + TILE_H - 1))
      end
      if feature_map & TILE_RIGHT ~= 0 then
        blit.pixel(Point(tile_x + TILE_W - 1, tile_y + TILE_H - 1))
      end
    end
  end

  return tile
end

function generate_new_row_mask()
  local new_row_mask = 0x0000
  local passage_width = math.floor(((math.sin(current_row / 10.0) + 1.0) / 2.0) * PASSAGE_COUNT)

  -- Cut our consistent winding passage through the level
  -- by tracking the x coord of our passage we can ensure
  -- that it's always navigable without having to reject
  -- procedurally generated segments
  for p = 0, PASSAGE_COUNT - 1 do
    if p <= passage_width then
      -- Controls how far a passage can snake left/right
      local turning_size = get_random_number() % 7

      new_row_mask = new_row_mask | (0x8000 >> passages[p])

      -- At every new generation we choose to branch a passage
      -- either left or right, or let it continue upwards.
      local num = get_random_number() % 3

      if num == 0 then  -- Passage goes right
        while turning_size > 0 do
          if passages[p] < TILES_X - 2 then
            passages[p] = passages[p] + 1
          end
          new_row_mask = new_row_mask | (0x8000 >> passages[p])
          turning_size = turning_size - 1
        end
      elseif num == 1 then -- Passage goes left
        while turning_size > 0 do
          if passages[p] > 1 then
            passages[p] = passages[p] - 1
          end
          new_row_mask = new_row_mask | (0x8000 >> passages[p])
          turning_size = turning_size - 1
        end
      end
    end
  end


  -- Whenever we have a narrowing of our passage we must check
  -- for orphaned passages and link them back to the ones still
  -- available, to avoid the player going up a tunnel that ends
  -- abruptly :(
  -- This routine picks a random passage from the ones remaining
  -- and routes every orphaned passage to it.
  if passage_width < last_passage_width then
    local target_passage = get_random_number() % (passage_width + 1)
    local target_p_x = passages[target_passage]

    for i = passage_width, last_passage_width do
      new_row_mask = new_row_mask | (0x8000 >> passages[i])
      

      local direction
      if passages[i] < target_p_x then direction = 1 else direction = -1 end

      while passages[i] ~= target_p_x do
        passages[i] = passages[i] + direction
        new_row_mask = new_row_mask | (0x8000 >> passages[i])
      end
    end
  end
  last_passage_width = passage_width

  current_row = current_row + 1
  return ~new_row_mask
end

function update_tiles()
  -- Shift all of our tile rows down by 1 starting
  -- with the second-to-bottom tile which replaces
  -- the bottom-most tile.
  for y = TILES_Y - 2, 0, -1 do
    for x = 0, TILES_X - 1 do
      local tgt = ((y + 1) * TILES_X) + x
      local src = (y * TILES_X) + x
      tiles[tgt] = tiles[src]
    end
  end

  local row_mask = generate_new_row_mask()

  -- Replace the very top row of tiles with our newly
  -- generated row mask.
  for x = 0, TILES_X - 1 do
    if row_mask & (1 << x) ~= 0 then
      tiles[x] = TILE_SOLID
    else
      tiles[x] = 0
    end
  end
end

-- update_state

function place_player()
  -- Try to find a suitable place to drop the player
  -- where they will be standing on solid ground
  for y = 10, 1, -1 do
    for x = 0, TILES_X - 1 do
      local here = get_tile_at(x, y)
      local below = get_tile_at(x, y + 1)
      
      if (below & TILE_SOLID) ~= 0 and (here & TILE_SOLID) == 0 then
        player_position.x = (x * TILE_W) + 4
        player_position.y = (y * TILE_H) + tile_offset.y
        return true
      end
    end
  end

  return false
end

function new_level()
  prng_lfsr = current_random_seed

  player_position.x = 80.0
  player_position.y = (SCREEN_H - PLAYER_H)
  player_velocity.x = 0.0
  player_velocity.y = 0.0
  player_progress = 0
  tile_offset.y = -10
  tile_offset.x = 0
  water_level = 0
  last_passage_width = 0
  current_row = 0

  for x = 0, 4 do
    passages[x] = (get_random_number() % 14) + 1
  end

  -- Use update_tiles to create the initial game state
  -- instead of having a separate loop that breaks in weird ways
  for y = 0, TILES_Y - 1 do
    update_tiles()
  end

  place_player();
end

function new_game()
  new_level()
  game_state = enum_state.play
end

function init()
  --set_screen_mode(lores)
  --AUDIO
  --state_update.init(update_state, 10, -1)
  --state_update.start()
  new_level()
end

--collide_player_lr
--collide_player_ud

function update(time)

end

function render_summary()
  local text = "Game mode: "

  if current_random_source == RANDOM_TYPE_PRNG then
    text = text .. "Competitive"
  else
    text = text .. "Random Practice"
  end
  blit.text(text, minimal_font, Point(10, (SCREEN_H / 2) + 20))

  if current_random_source == RANDOM_TYPE_PRNG then
    text = string.format("Level seed: %08X", current_random_seed)
    blit.text(text, minimal_font, Point(10, (SCREEN_H / 2) + 30))
  end

  text = "Press B"
  blit.text(text, minimal_font, Point(10, (SCREEN_H / 2) + 40))
end

function render(time_ms)
  blit.pen(Pen(0, 0, 0))
  blit.clear()
  local text = "RAINBOW ASCENT"

  if game_state == enum_state.menu then
    for_each_tile(render_tile, tile_offset)

    -- Draw the player
    blit.pen(Pen(255, 255, 255))
    blit.rectangle(Rect(player_position.x, player_position.y, PLAYER_W, PLAYER_H))
    blit.pen(Pen(255, 50, 50))
    blit.rectangle(Rect(player_position.x, player_position.y, PLAYER_W, 1))

    blit.pen(Pen(0, 0, 0, 200))
    blit.clear()

    local x = 10
    for i = 1, string.len(text) do
      local y = 20 + (5.0 * math.sin((time_ms / 250.0) + (x / string.len(text) * 2.0 * math.pi)))
      local color_letter = blit.hsv_to_rgba((x - 10) / 140.0, 0.5, 0.8)
      blit.pen(color_letter)

      local char = string.sub(text, i, i)
      blit.text(char, minimal_font, Point(x, y))
      x = x + 10;
    end

    blit.pen(Pen(255, 255, 255, 150))

    render_summary();

    return
  end
  --[[

  local color_water = hsv_to_rgba(((120 - 120) + 110.0) / 120.0, 1.0f, 0.5);
  color_water.a = 255

  if(water_level > 0){
      blit.pen(color_water)
      blit.rectangle(Rect(0, SCREEN_H - water_level, SCREEN_W, water_level + 1));

      for(auto x = 0; x < SCREEN_W; x++){
          uint16_t offset = x + uint16_t(sinf(time_ms / 500.0f) * 5.0f);
          if((offset % 5) > 0){
              blit.pixel(Point(x, SCREEN_H - water_level - 1));
          }
          if(((offset + 2) % 5) == 0){
              blit.pixel(Point(x, SCREEN_H - water_level - 2));
          }
          if(((offset + 3) % 5) == 0){
              blit.pixel(Point(x, SCREEN_H - water_level - 2));
          }
      }
  }

  for_each_tile(render_tile, (void *)&tile_offset);

  -- Draw the player
  blit.pen(Pen(255, 255, 255))
  blit.rectangle(Rect(player_position.x, player_position.y, PLAYER_W, PLAYER_H));
  blit.pen(Pen(255, 50, 50))
  blit.rectangle(Rect(player_position.x, player_position.y, PLAYER_W, 1));

  --[[
  -- Show number of active passages
  p = std::to_string(passage_width + 1);
  p.append(" passages");
  blit.text(p, minimal_font, point(2, 10));
  ]]
  --[[

  if(water_level > 0){
      color_water.a = 100;
      blit.pen = color_water;
      blit.rectangle(Rect(0, SCREEN_H - water_level, SCREEN_W, water_level + 1));

      for(auto x = 0; x < SCREEN_W; x++){
          uint16_t offset = x + uint16_t(sinf(time_ms / 500.0f) * 5.0f);
          if((offset % 5) > 0){
              blit.pixel(Point(x, SCREEN_H - water_level - 1));
          }
          if(((offset + 2) % 5) == 0){
              blit.pixel(Point(x, SCREEN_H - water_level - 2));
          }
          if(((offset + 3) % 5) == 0){
              blit.pixel(Point(x, SCREEN_H - water_level - 2));
          }
      }
  }

  if(game_state == enum_state::dead) {
      blit.pen(Pen(128, 0, 0, 200))
      blit.rectangle(Rect(0, 0, SCREEN_W, SCREEN_H));
      blit.pen(Pen(255, 0, 0, 255))
      blit.text("YOU DIED!", minimal_font, Point((SCREEN_W / 2) - 20, (SCREEN_H / 2) - 4));

      -- Round stats
      blit.pen(Pen(255, 255, 255))

      std::string text = "";

      text = "You climbed: ";
      text.append(std::to_string(player_progress));
      text.append("cm");
      blit.text(text, minimal_font, Point(10, (SCREEN_H / 2) + 10));

      render_summary();
  }
  else
  {
      -- Draw the HUD
      blit.pen(Pen(255, 255, 255))

      text = std::to_string(player_progress);
      text.append("cm");
      blit.text(text, minimal_font, Point(2, 2));

      --[[
      -- State debug info
      text = "Jumps: ";
      text.append(std::to_string(player_jump_count));
      blit.text(text, minimal_font, point(2, 12));

      text = "State: ";
      switch(player_state){
          case enum_player_state::ground:
              text.append("GROUND");
              break;
          case enum_player_state::air:
              text.append("AIR");
              break;
          case enum_player_state::near_wall_left:
              text.append("NEAR L");
              break;
          case enum_player_state::wall_left:
              text.append("WALL L");
              break;
          case enum_player_state::near_wall_right:
              text.append("NEAR R");
              break;
          case enum_player_state::wall_right:
              text.append("WALL R");
              break;
      }
      blit.text(text, minimal_font, point(2, 22));
      ]]
  --}
end
