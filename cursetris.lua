#!/usr/local/bin/luajit
-- cursetris.lua
--
-- A tetris-inspired game made using the curses library.
--

local curses = require 'curses'
local posix  = require 'posix'


------------------------------------------------------------------
-- Piece shapes.
------------------------------------------------------------------

-- pieces[shape_num][rot_num] = <string value of piece shape>
-- The hot spot is marked as * to help us be aware that this is
-- the point stored as (fall_x, fall_y).

pieces = {
  {
    '....' ..
    '.x..' ..
    'x*x.' ..
    '....'
  },
  {
    '....' ..
    '.xx.' ..
    'x*..' ..
    '....'
  },
  {
    '....' ..
    'xx..' ..
    '.*x.' ..
    '....'
  },
  {
    '....' ..
    '....' ..
    'x*xx' ..
    '....'
  },
  {
    '....' ..
    '.xx.' ..
    '.*x.' ..
    '....'
  },
  {
    '....' ..
    '.x..' ..
    '.*xx' ..
    '....'
  },
  {
    '....' ..
    '..x.' ..
    'x*x.' ..
    '....'
  },
}

------------------------------------------------------------------
-- Declare internal globals.
------------------------------------------------------------------

local stdscr = nil

local x_size = 11
local y_size = 20

-- board[x][y] = <piece index at (x, y)>
local board = {}

-- The fall_interval is the number of seconds between
-- quantum downward piece movements. The player is free
-- to move the piece faster than this.
local fall_interval = 0.7
local last_fall_at  = nil  -- Timestamp of the last fall event.

local fall_piece      -- Which piece is falling.
local fall_x, fall_y  -- Where the falling piece is.
local fall_rot

-- These are useful for calling set_color.
local colors = { white = 1, blue = 2, cyan = 3, green = 4,
                 magenta = 5, red = 6, yellow = 7, black = 8 }
local text_color = 9

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
end

-- Accepts integer values corresponding to the 'colors' table
-- created above. For example, call 'set_color(colors.black)'.
local function set_color(c)
  stdscr:attron(curses.color_pair(c))
end

local function new_falling_piece()
  fall_piece = math.random(#pieces)
  fall_x, fall_y = 6, 3
  fall_rot = 1
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
  stdscr:clear()
end

local function init()
  --math.randomseed(now()) -- TEMP
  -- Early calls to math.random() seem to give nearby values for nearby seeds,
  -- so let's call it a few times to lower the correlation.
  for i = 1,10 do math.random() end

  last_fall_at = now()

  init_curses()

  -- The board includes boundaries.
  for x = 0, x_size + 1 do
    board[x] = {}
    for y = 1, y_size + 1 do
      val = 0
      if x == 0 or x == x_size + 1 or y == y_size + 1 then
        val = -1
      end
      board[x][y] = val
    end
  end

  new_falling_piece()
end

local function draw_point(x, y, c)
  point_char = ' '
  if c and c > 0 then set_color(c) end
  if c and c == -1 then
    set_color(text_color)
    point_char = '|'
  end
  stdscr:mvaddstr(y, 2 * x + 0, point_char)
  stdscr:mvaddstr(y, 2 * x + 1, point_char)
end

-- pi      = piece index (1-#pieces)
-- rot_num = rotation number (1-4)
-- px, py  = x, y coordinates in piece space
local function get_piece_part(pi, rot_num, px, py)
  local p_str = pieces[pi][rot_num]
  set_color(text_color)
  local index = px + 4 * (py - 1)
  --return p_str:byte(index) ~= ord('.')
  ---[[
  ret = p_str:byte(index) ~= ord('.')
  if px == 1 and py == 4 then
    stdscr:mvaddstr(7, 50, 'p_str=' .. p_str)
    stdscr:mvaddstr(8, 50, tostring(ret))
    stdscr:mvaddstr(9, 50, '(px, py)=(' .. px .. ', ' .. py .. ')  ')
    stdscr:mvaddstr(10, 50, 'index=' .. index)
    stdscr:mvaddstr(11, 50, 'p_str:byte(index)=' .. p_str:byte(index))
    stdscr:mvaddstr(12, 50, 'ord(\'.\')=' .. ord('.'))
  end
  return ret
  --]]
end

-- Returns true iff the move was valid.
local function move_fall_piece_if_valid(new_x, new_y, new_rot)
  set_color(text_color)
  stdscr:mvaddstr(1, 50, 'move_fall_piece_if_valid(' .. new_x .. ', ' .. new_y .. ', ' .. new_rot .. ')')
  for x = 1, 4 do
    for y = 1, 4 do
      stdscr:mvaddstr(2, 50, '(x,y)=(' .. x .. ', ' .. y .. ') ')
      local p_part = get_piece_part(fall_piece, new_rot, x, y)
      local bx, by = new_x + x - 2, new_y + y - 3
      stdscr:mvaddstr(3, 50, '(bx, by)=(' .. bx .. ', ' .. by .. ') ')
      stdscr:mvaddstr(4, 50, 'p_part=' .. tostring(p_part))
      if p_part and (board[bx] == nil or board[bx][by] ~= 0) then
        stdscr:mvaddstr(5, 50, 'false')
        stdscr:mvaddstr(5, 60, 'p_part=' .. tostring(p_part) .. ' board[bx]=' .. tostring(board[bx]))
        return false
      end
    end
  end
  fall_x, fall_y, fall_rot = new_x, new_y, new_rot
  stdscr:mvaddstr(5, 20, 'true ')
  return true
end

local function draw_board()
  -- Draw the non-falling pieces.
  for x = 0, x_size + 1 do
    for y = 1, y_size + 1 do
      color = board[x][y]
      if color == 0 then color = colors.black end
      draw_point(x, y, color)
      if x == x_size + 1 then
        set_color(text_color)
        stdscr:mvaddstr(y, 2 * x + 2, tostring(y))
      end
    end
  end

  -- Draw the currently-falling piece.
  local rot_num = 1
  set_color(fall_piece)
  for px = 1, 4 do
    for py = 1, 4 do
      p_part = get_piece_part(fall_piece, rot_num, px, py)
      if p_part then
        set_color(fall_piece)  -- TEMP
        draw_point(fall_x + px - 2, fall_y + py - 3)
      end
    end
  end
end

local function end_game()
  curses.endwin()
  os.exit(0)
end

local function sleep(interval)
  sec = math.floor(interval)
  usec = math.floor((interval - sec) * 1e9)
  posix.nanosleep(sec, usec)
end

local function handle_key(key)
  if key == ord('q') then end_game() end
  if key == curses.KEY_LEFT then
    move_fall_piece_if_valid(fall_x - 1, fall_y, fall_rot)
  end
  if key == curses.KEY_RIGHT then
    move_fall_piece_if_valid(fall_x + 1, fall_y, fall_rot)
  end
end

local function lock_falling_piece()
  for x = 1, 4 do
    for y = 1, 4 do
      local bx, by = fall_x + x - 2, fall_y + y - 3
      if get_piece_part(fall_piece, fall_rot, x, y) then
        board[bx][by] = fall_piece
      end
    end
  end
end

------------------------------------------------------------------
-- Main.
------------------------------------------------------------------

init()

local num_cycles = 0

-- Main loop.
while true do
  num_cycles = num_cycles + 1
  -- Handle key presses.
  local c = stdscr:getch()  -- Nonblocking.
  if c then handle_key(c) end

  -- Move the piece down if the time is right.
  local timestamp = now()
  if (timestamp - last_fall_at) > fall_interval then
    if not move_fall_piece_if_valid(fall_x, fall_y + 1, fall_rot) then
      lock_falling_piece()
      new_falling_piece()
    end
    -- fall_y = fall_y + 1
    last_fall_at = timestamp
  end

  draw_board()
  stdscr:refresh()

  -- Don't kill the cpu.
  -- Choose sleep_time <= 0.1 so that an integer multiple of
  -- sleep_time hits the fall_interval.
  local sleep_time = fall_interval / math.ceil(fall_interval / 0.001)
  if sleep_time > fall_interval then sleep_time = fall_interval / 2.0 end
  sleep(sleep_time)

  -- Uncomment the lines below to debug main loop timing.
  --[[
  set_color(text_color)
  stdscr:mvaddstr(40, 10, 'sleep_time=' .. tostring(sleep_time))
  stdscr:mvaddstr(41, 10, 'num_cyles=' .. tostring(num_cycles))
  --]]
end
