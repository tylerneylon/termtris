#!/usr/local/bin/luajit
-- cursetris.lua
--
-- A tetris-inspired game made using the curses library.
--

local curses = require 'curses'


-- Piece shapes.

-- pieces[shape_num][rot_num] = <string value of piece shape>

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
    'xx*.' ..
    '....'
  },
}

-- Declare internal globals.

local stdscr = nil


-- Internal functions.

local function draw_board()
  stdscr:attron(curses.color_pair(2))
  for x = 1, 11 do
    for y = 1, 20 do
      stdscr:attron(curses.color_pair(2 - ((x + y) % 2)))
      stdscr:mvaddstr(y, 2 * x + 0, ' ')
      stdscr:mvaddstr(y, 2 * x + 1, ' ')
    end
  end
end

-- Accepts a one-byte string as input and returns
-- the numeric value of the byte.
-- This is similar to Python's ord function.
local function ord(c)
  return tostring(c):byte(1)
end

curses.initscr()
curses.cbreak()
curses.echo(false)  -- not noecho
curses.nl(false)    -- not nonl
curses.start_color()
if not curses.has_colors() then
  curses.endwin()
  print('Bummer! Looks like your terminal doesn\'t support colors :\'(')
  os.exit(1)
end

curses.init_pair(1, curses.COLOR_WHITE, curses.COLOR_RED)
curses.init_pair(2, curses.COLOR_BLUE, curses.COLOR_BLUE)


stdscr = curses.stdscr()


stdscr:clear()
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
stdscr:nodelay(true)

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

