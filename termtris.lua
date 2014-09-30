#!/usr/local/bin/lua
-- termtris.lua
--
-- A tetris-inspired game made using the curses library.
--

local curses = require 'curses'
local posix  = require 'posix'

------------------------------------------------------------------
-- Piece shapes.
------------------------------------------------------------------

-- The final form of the shapes array is set up in init so
-- that at runtime, s = shapes[shape_num][rot_num] is a 2D array
-- with s[x][y] = either 0 or 1, indicating the piece's shape.

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

local game_state = 'playing'

local stdscr = nil

local board_size = {x = 11, y = 20}
local board = {}  -- board[x][y] = <piece at (x, y)>; 0 = empty, -1 = border.

-- We'll write *shape* for an index into the shapes table; the
-- term *piece* also includes a rotation number and x, y coords.
local moving_piece = {}  -- Keys will be: shape, rot_num, x, y.


------------------------------------------------------------------
-- Internal functions.
------------------------------------------------------------------

-- Accepts integer values corresponding to the 'colors' table
-- created by init. For example, call 'set_color(colors.black)'.
local function set_color(c)
  stdscr:attron(curses.color_pair(c))
end

-- This function calls callback(x, y) for each x, y coord
-- in the given piece. Example use using draw_point(x, y):
-- call_fn_for_xy_in_piece(moving_piece, draw_point)
local function call_fn_for_xy_in_piece(piece, callback, param)
  local s = shapes[piece.shape][piece.rot_num]
  for x, row in ipairs(s) do
    for y, val in ipairs(row) do
      if val == 1 then callback(piece.x + x, piece.y + y, param) end
    end
  end
end

local function draw_point(x, y, x_offset, color, point_char)
  point_char = point_char or ' '
  if color then set_color(color) end
  -- Don't draw pieces when the game is paused.
  if point_char == ' ' and game_state == 'paused' then return end
  stdscr:mvaddstr(y, x_offset + 2 * x + 0, point_char)
  stdscr:mvaddstr(y, x_offset + 2 * x + 1, point_char)
end

-- Returns true iff the move was valid.
local function set_moving_piece_if_valid(piece)
  -- Use values of moving_piece as defaults.
  for k, v in pairs(moving_piece) do
    if piece[k] == nil then piece[k] = moving_piece[k] end
  end
  local is_valid = true
  call_fn_for_xy_in_piece(piece, function (x, y)
    if board[x] and board[x][y] ~= 0 then is_valid = false end
  end)
  if is_valid then moving_piece = piece end
  return is_valid
end

local function init()
  -- Use the current time's microseconds as our random seed.
  math.randomseed(posix.gettimeofday().usec)

  -- Set up the shapes table.
  for s_index, s in ipairs(shapes) do
    shapes[s_index] = {}
    for rot_num = 1, 4 do
      -- Rotate shape s by 90 degrees.
      local new_shape = {}
      local x_end = #s[1] + 1  -- Chosen so that x_end - x is in [1, x_max].
      for x = 1, #s[1] do      -- Coords x & y are indexes for the new shape.
        new_shape[x] = {}
        for y = 1, #s do
          new_shape[x][y] = s[y][x_end - x]
        end
      end
      s = new_shape
      shapes[s_index][rot_num] = s
    end
  end

  -- Start up curses.
  curses.initscr()    -- Initialize the curses library and the terminal screen.
  curses.cbreak()     -- Turn off input line buffering.
  curses.echo(false)  -- Don't print out characters as the user types them.
  curses.nl(false)    -- Turn off special-case return/newline handling.
  curses.curs_set(0)  -- Hide the cursor.

  -- Set up colors.
  curses.start_color()
  if not curses.has_colors() then
    curses.endwin()
    print('Bummer! Looks like your terminal doesn\'t support colors :\'(')
    os.exit(1)
  end
  local colors = { white = 1, blue = 2, cyan = 3, green = 4,
                   magenta = 5, red = 6, yellow = 7, black = 8 }
  for k, v in pairs(colors) do
    curses_color = curses['COLOR_' .. k:upper()]
    curses.init_pair(v, curses_color, curses_color)
  end
  colors.text, colors.over = 9, 10
  curses.init_pair(colors.text, curses.COLOR_WHITE, curses.COLOR_BLACK)
  curses.init_pair(colors.over, curses.COLOR_RED,   curses.COLOR_BLACK)

  -- Set up our standard screen.
  stdscr = curses.stdscr()
  stdscr:nodelay(true)  -- Make getch nonblocking.
  stdscr:keypad()       -- Correctly catch arrow key presses.

  -- Set the board; 0 for empty; -1 for border cells.
  local border = {x = board_size.x + 1, y = board_size.y + 1}
  for x = 0, border.x do
    board[x] = {}
    for y = 1, border.y do
      board[x][y] = 0
      if x == 0 or x == border.x or y == border.y then
        board[x][y] = -1  -- This is a border cell.
      end
    end
  end

  -- Set up the next and currently moving piece.
  moving_piece = {shape = math.random(#shapes), rot_num = 1, x = 4, y = 0}
  -- Use a table so functions can edit its value without having to return it.
  next_piece = {shape = math.random(#shapes)}

  local stats = {level = 1, lines = 0, score = 0}  -- Player stats.

  -- fall.interval is the number of seconds between downward piece movements.
  local fall = {interval = 0.7}  -- A 'last_at' time is added to this table later.

  return stats, fall, colors, next_piece
end

local function draw_screen(stats, colors, next_piece)
  stdscr:erase()

  -- Update the screen dimensions.
  local scr_width = curses.cols()
  local win_width = 2 * (board_size.x + 2) + 16
  local x_margin = math.floor((scr_width - win_width) / 2)
  local x_labels = x_margin + win_width - 10

  -- Draw the board's border and non-falling pieces if we're not paused.
  local color_of_val = {[-1] = colors.text, [0] = colors.black}
  local char_of_val = {[-1] = '|'}  -- This is the border character.
  if game_state == 'over' then color_of_val[-1] = colors.over end
  for x = 0, board_size.x + 1 do
    for y = 1, board_size.y + 1 do
      local board_val = board[x][y]
      -- Draw ' ' for shape & empty points; '|' for border points.
      local pt_char = char_of_val[board_val] or ' '
      draw_point(x, y, x_margin, color_of_val[board_val] or board_val, pt_char)
    end
  end

  -- Write 'paused' if the we're paused; draw the moving piece otherwise.
  if game_state == 'paused' then
    set_color(colors.text)
    local x = x_margin + board_size.x - 1
    stdscr:mvaddstr(math.floor(board_size.y / 2), x, 'paused')
  else
    set_color(moving_piece.shape)
    call_fn_for_xy_in_piece(moving_piece, draw_point, x_margin)
  end

  -- Draw the stats: level, lines, and score.
  set_color(colors.text)
  stdscr:mvaddstr( 9, x_labels, 'Level ' .. stats.level)
  stdscr:mvaddstr(11, x_labels, 'Lines ' .. stats.lines)
  stdscr:mvaddstr(13, x_labels, 'Score ' .. stats.score)
  if game_state == 'over' then
    stdscr:mvaddstr(16, x_labels, 'Game Over')
  end

  -- Draw the next piece.
  set_color(colors.text)
  stdscr:mvaddstr(2, x_labels, '----------')
  stdscr:mvaddstr(7, x_labels, '---Next---')
  local piece = {shape = next_piece.shape, rot_num = 1, x = board_size.x + 5, y = 3}
  set_color(piece.shape)
  call_fn_for_xy_in_piece(piece, draw_point, x_margin)

  stdscr:refresh()
end

local function lock_and_update_moving_piece(stats, fall, next_piece)
  call_fn_for_xy_in_piece(moving_piece, function (x, y)
    board[x][y] = moving_piece.shape  -- Lock the moving piece in place.
  end)

  -- Clear any lines possibly filled up by the just-placed piece.
  local num_removed = 0
  local max_line_y = math.min(moving_piece.y + 4, board_size.y)
  for line_y = moving_piece.y + 1, max_line_y do
    local is_full_line = true
    for x = 1, board_size.x do
      if board[x][line_y] == 0 then is_full_line = false end
    end
    if is_full_line then
      -- Remove the line at line_y.
      for y = line_y, 2, -1 do
        for x = 1, board_size.x do
          board[x][y] = board[x][y - 1]
        end
      end
      -- Record the line and level updates.
      stats.lines = stats.lines + 1
      if stats.lines % 10 == 0 then  -- Level up when lines is a multiple of 10.
        stats.level = stats.level + 1
        fall.interval = fall.interval * 0.8
      end
      num_removed = num_removed + 1
    end
  end
  if num_removed > 0 then curses.flash() end
  stats.score = stats.score + num_removed * num_removed

  -- Bring in the waiting next piece and set up a new next piece.
  moving_piece = {shape = next_piece.shape, rot_num = 1, x = 4, y = 0}
  if not set_moving_piece_if_valid(moving_piece) then
    game_state = 'over'
  end
  next_piece.shape = math.random(#shapes)
end

local function handle_input(stats, fall, next_piece)
  local key = stdscr:getch()  -- Nonblocking; returns nil if no key was pressed.
  if key == nil then return end

  if key == tostring('q'):byte(1) then  -- The q key quits.
    curses.endwin()
    os.exit(0)
  end

  if key == tostring('p'):byte(1) then  -- The p key pauses or unpauses.
    local switch = {playing = 'paused', paused = 'playing'}
    if switch[game_state] then game_state = switch[game_state] end
  end
  
  if game_state ~= 'playing' then return end  -- Arrow keys only work if playing.

  -- Handle the left, right, or up arrows.
  local new_rot_num = (moving_piece.rot_num % 4) + 1  -- Map 1->2->3->4->1.
  local moves = {[curses.KEY_LEFT]  = {x = moving_piece.x - 1},
                 [curses.KEY_RIGHT] = {x = moving_piece.x + 1},
                 [curses.KEY_UP]    = {rot_num = new_rot_num}}
  if moves[key] then set_moving_piece_if_valid(moves[key]) end

  -- Handle the down arrow.
  if key == curses.KEY_DOWN then
    while set_moving_piece_if_valid({y = moving_piece.y + 1}) do end
    lock_and_update_moving_piece(stats, fall, next_piece)
  end
end

local function lower_piece_at_right_time(stats, fall, next_piece)
  -- This function does nothing if the game is paused or over.
  if game_state ~= 'playing' then return end

  local timeval = posix.gettimeofday()
  local timestamp = timeval.sec + timeval.usec * 1e-6
  if fall.last_at == nil then fall.last_at = timestamp end

  -- Do nothing until it's been fall.interval seconds since the last fall.
  if timestamp - fall.last_at < fall.interval then return end
 
  if not set_moving_piece_if_valid({y = moving_piece.y + 1}) then
    lock_and_update_moving_piece(stats, fall, next_piece)
  end
  fall.last_at = timestamp
end

------------------------------------------------------------------
-- Main.
------------------------------------------------------------------

local function main()
  local stats, fall, colors, next_piece = init()

  while true do  -- Main loop.

    handle_input(stats, fall, next_piece)
    lower_piece_at_right_time(stats, fall, next_piece)
    draw_screen(stats, colors, next_piece)

    -- Don't poll for input much faster than the display can change.
    local sec, nsec = 0, 5e6  -- 0.005 seconds.
    posix.nanosleep(sec, nsec)
  end
end

main()
