#!/usr/local/bin/luajit
-- termtris.lua
--
-- A tetris-inspired game made using the curses library.
--

local curses = require 'curses'
local posix  = require 'posix'

------------------------------------------------------------------
-- Piece shapes.
------------------------------------------------------------------

-- At runtime, pieces[shape_num][rot_num] is a 2D array p so that
-- p[x][y] is either 0 or 1, indicating where the piece lives.
-- The final form of the pieces array is set up by init_shapes.

local shapes = {
  { {0, 1, 0},
    {1, 1, 1}
  },
  { {0, 1, 1},
    {1, 1, 0}
  }, 
  { {1, 1, 0},
    {0, 1, 1}
  },
  { {1, 1, 1, 1}
  },
  { {1, 1},
    {1, 1}
  },
  { {1, 0, 0},
    {1, 1, 1}
  },
  { {0, 0, 1},
    {1, 1, 1}
  }
}

------------------------------------------------------------------
-- Declare internal globals.
------------------------------------------------------------------

local stdscr = nil

local board_size = {x = 11, y = 20}

-- board[x][y] = <piece index at (x, y)>; 0 = empty, -1 = border.
local board = {}

-- The fall_interval is the number of seconds between
-- quantum downward piece movements. The player is free
-- to move the piece faster than this.
local fall_interval = 0.7
local last_fall_at  = nil  -- Timestamp of the last fall event.
local stats = {level = 1, lines = 0, score = 0}

-- We use the *shape* for an index into the shapes table; the
-- term *piece* also includes a rotation number and x, y coords.
local moving_piece = {}  -- Keys will be: shape, rot_num, x, y.
local next_shape

-- These are useful for calling set_color.
local colors = { white = 1, blue = 2, cyan = 3, green = 4,
                 magenta = 5, red = 6, yellow = 7, black = 8 }
local text_color = 9
local  end_color = 10

local game_state = 'playing'

local screen_dims = {}

------------------------------------------------------------------
-- Internal functions.
------------------------------------------------------------------

-- Accepts a one-byte string as input and returns
-- the numeric value of the byte.
-- This is similar to Python's ord function.
local function ord(c)
  return tostring(c):byte(1)
end

local function now()
  timeval = posix.gettimeofday()
  return timeval.sec + timeval.usec * 1e-6
end

local function init_colors()
  curses.start_color()
  if not curses.has_colors() then
    curses.endwin()
    print('Bummer! Looks like your terminal doesn\'t support colors :\'(')
    os.exit(1)
  end

  for k, v in pairs(colors) do
    curses_color = curses['COLOR_' .. k:upper()]
    curses.init_pair(v, curses_color, curses_color)
  end
  curses.init_pair(text_color, curses.COLOR_WHITE, curses.COLOR_BLACK)
  curses.init_pair( end_color, curses.COLOR_RED,   curses.COLOR_BLACK)
end

-- Accepts integer values corresponding to the 'colors' table
-- created above. For example, call 'set_color(colors.black)'.
local function set_color(c)
  stdscr:attron(curses.color_pair(c))
end

-- Refresh the user-visible stats such as level and score.
local function update_stats()
  set_color(text_color)
  stdscr:mvaddstr( 9, screen_dims.x_labels, 'Level ' .. stats.level)
  stdscr:mvaddstr(11, screen_dims.x_labels, 'Lines ' .. stats.lines)
  stdscr:mvaddstr(13, screen_dims.x_labels, 'Score ' .. stats.score)
  if game_state == 'over' then
    stdscr:mvaddstr(16, screen_dims.x_labels, 'Game Over')
  end
end

-- This function iterates over all x, y coords of a piece
-- anchored at the given px, py coordinates. Example use:
-- for x, y in piece_coords(piece) do draw_at(x, y) end
local function piece_coords(piece)
  local s = shapes[piece.shape][piece.rot_num]
  local x, y = 0, 1
  local x_end, y_end = #s + 1, #s[1] + 1
  return function ()
    repeat
      x = x + 1
      if x == x_end then x, y = 1, y + 1 end
    until y == y_end or s[x][y] == 1
    if y ~= y_end then return piece.x + x, piece.y + y end
  end
end

local function draw_point(x, y, color)
  point_char = ' '
  if color and color > 0 then set_color(color) end
  if color and color == -1 then
    set_color(text_color)
    if game_state == 'over' then set_color(end_color) end
    point_char = '|'
  elseif game_state == 'paused' then
    return  -- Only draw border pieces while paused.
  end
  local x_offset = screen_dims.x_margin
  stdscr:mvaddstr(y, x_offset + 2 * x + 0, point_char)
  stdscr:mvaddstr(y, x_offset + 2 * x + 1, point_char)
end

local function show_next_piece()
  set_color(text_color)
  stdscr:mvaddstr(2, screen_dims.x_labels, '----------')
  stdscr:mvaddstr(7, screen_dims.x_labels, '---Next---')

  local piece = {shape = next_shape, rot_num = 1, x = board_size.x + 5, y = 3}
  for x, y in piece_coords(piece) do
    draw_point(x, y, next_shape)
  end
end

-- Returns true iff the move was valid.
local function set_moving_piece_if_valid(piece)
  -- Use values of moving_piece as defaults.
  for k, v in pairs(moving_piece) do
    if piece[k] == nil then piece[k] = moving_piece[k] end
  end
  for x, y in piece_coords(piece) do
    if board[x] and board[x][y] ~= 0 then return false end
  end
  moving_piece = piece
  return true
end

local function new_moving_piece()
  moving_piece = {shape = next_shape, rot_num = 1, x = 4, y = 0}
  if not set_moving_piece_if_valid(moving_piece) then
    game_state = 'over'
  end
  next_shape = math.random(#shapes)
end

local function update_screen_dims()
  local scr_width = curses.cols()
  local win_width = 2 * (board_size.x + 2) + 16
  screen_dims.x_margin = math.floor((scr_width - win_width) / 2)
  screen_dims.x_labels = screen_dims.x_margin + win_width - 10
end

local function init_curses()
  -- Start up curses.
  curses.initscr()
  curses.cbreak()
  curses.echo(false)  -- not noecho
  curses.nl(false)    -- not nonl
  local invisible = 0
  curses.curs_set(invisible)  -- Hide the cursor.

  init_colors()

  -- Set up our standard screen.
  stdscr = curses.stdscr()
  stdscr:nodelay(true)  -- Make getch nonblocking.
  stdscr:keypad()       -- Correctly catch arrow key presses.
end

local function rotate_shape(s)
  local new_shape = {}
  local y_end = #s[1] + 1  -- Chosen so that y_end - y is still in [1, y_max].

  for y = 1, #s[1] do
    new_shape[y] = {}
    for x = 1, #s do
      new_shape[y][x] = s[x][y_end - y]
    end
  end

  return new_shape
end

local function init_shapes()
  for s_index, s in ipairs(shapes) do
    shapes[s_index] = {}
    for rot_num = 1, 4 do
      s = rotate_shape(s)
      shapes[s_index][rot_num] = s
    end
  end
end

local function init()
  math.randomseed(now())

  last_fall_at = now()

  init_shapes()
  init_curses()

  -- Set the board; 0 for empty; -1 for border cells.
  for x = 0, board_size.x + 1 do
    for y = 1, board_size.y + 1 do
      board[x][y] = -1  -- Fill with -1's at first.
    end
  end
  for x = 1, board_size.x do
    for y = 1, board_size.y do
      board[x][y] = 0   -- Replace inside with 0's; border left as -1's.
    end
  end

  next_shape = math.random(#shapes)
  new_moving_piece()
end

local function draw_board()
  -- Draw the non-falling pieces.
  for x = 0, board_size.x + 1 do
    for y = 1, board_size.y + 1 do
      color = board[x][y]
      if color == 0 then color = colors.black end
      draw_point(x, y, color)  -- This doesn't draw pieces when we're paused.
    end
  end

  if game_state == 'paused' then
    set_color(text_color)
    local x = screen_dims.x_margin + board_size.x - 1
    stdscr:mvaddstr(math.floor(board_size.y / 2), x, 'paused')
    return
  end

  -- Draw the currently-moving piece.
  for x, y in piece_coords(moving_piece) do
    draw_point(x, y, moving_piece.shape)
  end
end

local function sleep(interval)
  sec = math.floor(interval)
  usec = math.floor((interval - sec) * 1e9)
  posix.nanosleep(sec, usec)
end

local function remove_line(remove_y)
  for y = remove_y, 2, -1 do
    for x = 1, board_size.x do
      board[x][y] = board[x][y - 1]
    end
  end
  stats.lines = stats.lines + 1
  if stats.lines % 10 == 0 then  -- Level up when lines is a multiple of 10.
    stats.level = stats.level + 1
    fall_interval = fall_interval * 0.8
  end
end

local function line_is_full(y)
  if y > board_size.y then return false end
  for x = 1, board_size.x do
    if board[x][y] == 0 then return false end
  end
  return true
end

-- This checks the 4 lines affected by the current moving piece,
-- which we expect to have just hit and been locked in at the bottom.
local function check_for_full_lines()
  local num_removed = 0
  for dy = 1, 4 do
    if line_is_full(moving_piece.y + dy) then
      remove_line  (moving_piece.y + dy)
      num_removed = num_removed + 1
    end
  end
  if num_removed > 0 then curses.flash() end
  stats.score = stats.score + num_removed * num_removed
end

local function moving_piece_hit_bottom()
  for x, y in piece_coords(moving_piece) do
    board[x][y] = moving_piece.shape  -- Lock the moving piece in place.
  end
  check_for_full_lines()
  new_moving_piece()
end

local function handle_key(key)
  if key == ord('q') then
    curses.endwin()
    os.exit(0)
  end

  if key == ord('p') then
    local switch = {playing = 'paused', paused = 'playing'}
    if switch[game_state] then game_state = switch[game_state] end
  end
  
  -- Don't respond to arrow keys if the game is over or paused.
  if game_state ~= 'playing' then return end

  if key == curses.KEY_LEFT then
    set_moving_piece_if_valid({x = moving_piece.x - 1})
  end
  if key == curses.KEY_RIGHT then
    set_moving_piece_if_valid({x = moving_piece.x + 1})
  end
  if key == curses.KEY_DOWN then
    while set_moving_piece_if_valid({y = moving_piece.y + 1}) do end
    moving_piece_hit_bottom()
  end
  if key == curses.KEY_UP then
    set_moving_piece_if_valid({rot_num = (moving_piece.rot_num % 4) + 1})
  end
end

local function lower_piece_at_right_time()
  -- This function does nothing if the game is paused or over.
  if game_state ~= 'playing' then return end

  local timestamp = now()
  if (timestamp - last_fall_at) > fall_interval then
    if not set_moving_piece_if_valid({y = moving_piece.y + 1}) then
      moving_piece_hit_bottom()
    end
    last_fall_at = timestamp
  end
end

------------------------------------------------------------------
-- Main.
------------------------------------------------------------------

init()

-- Main loop.
while true do

  -- Handle key presses.
  local key = stdscr:getch()  -- Nonblocking.
  if key then handle_key(key) end

  lower_piece_at_right_time()

  -- Drawing.
  stdscr:erase()
  update_screen_dims()
  draw_board()
  update_stats()
  show_next_piece()
  stdscr:refresh()

  sleep(0.002)  -- Be responsive but avoid killing the cpu.
end
