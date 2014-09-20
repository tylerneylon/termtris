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

local fall_piece      -- Which piece is falling.
local fall_x, fall_y  -- Where the falling piece is.

local colors = { white = 1, blue = 2, cyan = 3, green = 4,
                 magenta = 5, red = 6, yellow = 7, black = 8 }

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
end

-- Accepts integer values corresponding to the 'colors' table
-- created above. For example, call 'set_color(colors.black)'.
local function set_color(c)
  stdscr:attron(curses.color_pair(c))
end

local function init_curses()
  -- Start up curses.
  curses.initscr()
  curses.cbreak()
  curses.echo(false)  -- not noecho
  curses.nl(false)    -- not nonl

  init_colors()

  -- Set up our standard screen.
  stdscr = curses.stdscr()
  stdscr:nodelay(true)  -- Make getch nonblocking.
  stdscr:keypad()       -- Correctly catch arrow key presses.
  stdscr:clear()
end

local function init()
  math.randomseed(now())
  -- Early calls to math.random() seem to give nearby values for nearby seeds,
  -- so let's call it a few times to lower the correlation.
  for i = 1,10 do math.random() end

  init_curses()

  for x = 1, x_size do
    board[x] = {}
    for y = 1, y_size do
      board[x][y] = 0
    end
  end

  fall_piece = math.random(#pieces)
  fall_x, fall_y = 6, 3

end

local function draw_point(x, y, c)
  if c then set_color(c) end
  stdscr:mvaddstr(y, 2 * x + 0, ' ')
  stdscr:mvaddstr(y, 2 * x + 1, ' ')
end

-- pi      = piece index (1-#pieces)
-- rot_num = rotation number (1-4)
-- px, py  = x, y coordinates in piece space
local function get_piece_part(pi, rot_num, px, py)
  local p_str = pieces[pi][rot_num]
  local index = px + 4 * (py - 1)
  return p_str:byte(index) ~= ord('.')
end

local function draw_board()
  stdscr:attron(curses.color_pair(2))
  for x = 1, x_size do
    for y = 1, y_size do
      color = board[x][y]
      if color == 0 then color = colors.black end
      draw_point(x, y, color)
    end
  end

  -- Draw the currently-falling piece.
  local rot_num = 1
  set_color(fall_piece)
  for px = 1, 4 do
    for py = 1, 4 do
      p_part = get_piece_part(fall_piece, rot_num, px, py)
      if p_part then
        draw_point(fall_x + px - 2, fall_y + py - 3)
      end
    end
  end
end

local function end_game()
  curses.endwin()
  os.exit(0)
end


------------------------------------------------------------------
-- Main.
------------------------------------------------------------------

init()

-- Main loop.
while true do
  -- Handle key presses.
  local c = stdscr:getch()  -- Nonblocking.
  if c then
    if c == ord('q') then end_game() end
  end

  -- Move the piece down if the time is right.

  draw_board()
end


--stdscr:mvaddstr(15,20,'print out curses table (y/n) ? ')
draw_board()


a_str = [[
┌─┐
└─┘
]]

b_str = [[
┌──┐
│  │
└──┘
]]

c_str = [[
⏧⎸
⎾⏋
⎿h
]]


--stdscr:attron(curses.color_pair(1))
--stdscr:mvaddstr(16, 20, 'hi')


stdscr:refresh()

while true do
  local c = stdscr:getch()
  if c == ord('q') then
    curses.endwin()
    print('c=' .. tostring(c))
    print('type(c)=' .. type(c))
    print('(c == 113)=' .. tostring(c == 113))
    os.exit(0)
  end
  os.execute('sleep 0.5')
end
local c = stdscr:getch()
if c < 256 then c = string.char(c) end
curses.endwin()
if c == 'y' then
    table.sort(a)
    for i,k in ipairs(a) do print(type(curses[k])..'  '..k) end
end

print('c=' .. tostring(c))

