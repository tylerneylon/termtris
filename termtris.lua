--[[

# termtris: A Game like Tetris in Ten Functions

This is a literate implementation of a
tetris-like game called `termtris`.
You may be reading this as an html-ified version -
but the original,
[`termtris.lua`](https://github.com/tylerneylon/termtris/blob/master/termtris.lua),
is simultaneously a Lua file and a markdown file.
In the original file,
all the text between the --[​[ and --]​] comment delimiters are markdown
while everything else is code.

```
-- This is an example of a code block. Taken together, all the code
-- blocks in this document compose the complete termtris game.
```

![](https://raw.githubusercontent.com/tylerneylon/termtris/master/img/sample.gif)

This code has been written with an emphasis on readability
and learn-from-ability. I hope these comments are useful to anyone
interested in how a game like tetris can be made.
I've put some effort into making
this document friendly to coders who are new to Lua.

On github.com, the `readme.md` is a symbolic link to `termtris.lua`
to enable easy reading from
[the repo's home page](https://github.com/tylerneylon/termtris).
A nonliterate version of the code is in the file
[`plain_termtris.lua`](https://github.com/tylerneylon/termtris/blob/master/nonliterate/plain_termtris.lua).

I'll tell you how you can download and play `termtris`, and
then we'll dive into the code.

## Playing the game

You can play `termtris` on Mac OS X or linux/unix using a Lua interpreter.

You can download Lua [here](http://www.lua.org/download.html)
and the `luarocks` package manager [here](http://luarocks.org/en/Download).
If you already have a
higher-level installer like `brew` or `apt-get`, you might be able to use that
to get `lua` and `luarocks`.
From there:

* `sudo luarocks install luaposix`
* `git clone https://github.com/tylerneylon/termtris.git`
* `lua termtris/termtris.lua`

Here are the game controls:

| key                | action                           |
|--------------------|----------------------------------|
| left, right arrows | move the piece left or right     |
| up arrow           | rotate the piece                 |
| down arrow         | drop and lock the piece in place |
| `p`                | pause or unpause                 |
| `q`                | quit                             |

## Reading Lua

Even if you're new to Lua, I think you'll find it easy to understand
the code. I'll mention a few things that may not be obvious:

* Block comments are between `--[​[` and `--]​]`. Line-tail comments start with `--`.
* An assignment like `a, b, c = f()` calls `f` and assigns all of `f`'s
  return values to `a`, `b`, and `c` in order — not just to `c`.
* The token `~=` is the not-equal-to operator.
* The *only* compound data structure is called a *table*. It's an associative
  array that can map any non-nil Lua value to any other.
* Things inside curly braces `{}` are table literals.
  The literal `a = {x, y}` has values `a[1] == x` and `a[2] == y`.
  Table literals can be nested: if `a = {{x}, {y}}`, then `a[2][1] == y`.
* If `pi == 3.141`, then the literal `b = {w = 1, [pi] = 2}` results in
  `b.w == b['w'] == 1` and `b[pi] == 2`; that is, identifiers to the left of `=`
  are string keys and
  keys inside brackets `[]` are treated as general expressions.
* Using an undefined table key is not an error — it just returns `nil`, which is falsy.
  For example, if `a = {key1 = 'hi', key2 = 'there'}`, then `a.key3` is a valid
  expression with value `nil`.
* We can iterate over the keys and values of table `t` with the pattern
  `for k, v in pairs(t) do my_fn(k, v) end`. If `t` is treated as an array —
  if it has sequential integer keys starting at 1 — then `ipairs` can be used
  instead of `pairs` to ensure the keys are given in order:
  `for i, v in ipairs(t) do my_fn(i, v) end`.

Armed with that lightning flash of a Lua introduction, I believe you can understand
all of the code. For a tad more depth, some crazy guy claims you can
[learn the language in 15 minutes](http://tylerneylon.com/a/learn-lua/).

## The Code

This code has been written to maximize readability. This is hard to measure.
We can get a quantifiable hint that the code is not too daunting by consider its
line count and function count.

The code we'll examine has a total of 10 functions, and a little over
200 non-blank, non-comment lines of code:

```
$ # (This is a bash line, not part of the Lua code!)
$ egrep -v '^\s*(--|$)' nonliterate/plain_termtris.lua | wc -l
231
```

This is small for a game. We could have used even fewer functions or fewer lines, but
beyond a certain point the compressed code becomes more cryptic than simple.
The trick is to find a balance between brevity and clarity.

### Overview

Here's the complete call graph for `termtris`:

![](https://raw.githubusercontent.com/tylerneylon/termtris/master/img/termtris_call_graph.png)

The `main` function initializes our data and then enters a game loop
in which we consistently check for input, drop the moving piece if the time
is right, and update what is drawn on the screen.

We'll understand the full code by looking at the libraries used for drawing and
timing, then going through the code more-or-less in the order that it's
executed.

### Libraries

**curses:**
Tetris is a visually-oriented game, so we need a way to draw. A simple and
somewhat-portable way to do this is to draw colored space characters in
the terminal. We can do this using a time-tested library called `curses`.

**posix:**
We also need accurate timing information. Lua comes with functions like
`os.clock()` and `os.time()`, but neither of these are appropriate for a
game clock. The `os.clock()` function returns cpu time, rather than wall-clock
time; the difference is that cpu time only passes when our process is actually
running on the cpu, while wall-clock marches on no matter what process is
running. Users think in wall-clock time, so that's what we want.

The `os.time()` function gives us the wall-clock time, but only in seconds.
We'd like pieces to move faster than once per second! To achieve this, we
import the `posix` library, which gives us access to more advanced posix
functions, including higher-resolution timestamps.

Both of these libraries are installed together by running
the `luarocks install luaposix` command mentioned in the installation
section above.

Below are our module imports. This is the first "real"
code block, unlike the non-running example code sections above.
From here till the end, all code blocks are part of
the official program.

--]]

    local curses = require 'curses'
    local posix  = require 'posix'

--[[

---

### Function 1: The Main Loop

Let's take a look at our game loop, which lives in a function called `main`.

This function will initialize the game state by calling `init`, then enter
a seemingly-infinite `while true` loop that executes the game.
The loop isn't really infinte because we can call `os.exit` when the player
presses `q` to quit.

A few local variables are going to be used:

| local var    | what it does                                          |
|--------------|-------------------------------------------------------|
| `stats`      | Track the player's line count, level and score.       |
| `fall`       | Track the speed and timing of the falling piece.      |
| `colors`     | A table to conveniently access text color attributes. |
| `next_piece` | Track which piece is coming up next.                  |

All of these are tables so that they can be modified by functions as
parameters, and have those changes persist after the function has completed.
This makes the code less functional in style, but since most parameters
are used as both input and output, it simplifies the code nicely.

We'll also use a small number of globals. It's considered good practice
to minimize global variable use. The global variables in this file either
act as constants or are used so widely that passing them to many functions
felt messier to me than leaving them as globals.

Our main game loop takes three actions: check for any input, lower the
current piece if the time is right, and redraw the screen. We also have
a short delay to avoid using 100% of the cpu.

Below is the main function. We'll examine each of the called
functions as we define them.

--]]

    function main()
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

--[[

### Shape data

Next let's set up all possible shape pieces.
We'll use a global table called `shapes` for this.

There are seven possibilities:

![](https://raw.githubusercontent.com/tylerneylon/termtris/master/img/the_seven_shapes.png)

The `shapes` table will be indexed first by shape number (1-7), and
then by a rotation number (1-4). So `s = shapes[5][1]` represents shape number 5 in its
first rotation orientation. This variable `s` represents the shape so that `s[x][y]` is
either 0 or 1; its value is 1 if the shape exists in the given `(x, y)` cell.

There are 7 shapes and 4 rotated orientations for each, giving 28 possible shape grids.
Instead of initializing all of them by hand, we'll set up one orientation of each shape,
and include some code in `init` that expands the `shapes` variable to include all
28 possibilities.

Even though the `shape` variable - and others defined below - are global to this file, we declare
them with the `local` keyword so that any other Lua code importing this file won't have
these variables in scope. In a sense, they become 'locally global.'

--]]

    -- Set up one orientation of each shape.

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

--[[

### Global game state

We'll use globals to conceptually track the following items:

| global var          | description                                                                     |
|---------------------|---------------------------------------------------------------------------------|
| `game_state`        | Whether the game is playing, paused, or over.                                   |
| `board`             | Where pieces have already been placed on the game board.                        |
| `board_size`, `val` | Effectively, board-related constants to reduce magic numbers in the code.       |
| `stdscr`            | A `curses`-library window object for drawing to the screen.                     |
| `moving_piece`      | Which piece is currently falling: it has keys `shape`, `rot_num`, `x`, and `y`. |

The name `rot_num` is used for rotation numbers.

#### Game state

We'll use strings values to track if the game is playing, paused, or over. This would be a good
place to use an enum, but Lua doesn't have an enum equivalent.

--]]

    local game_state = 'playing'  -- Could also be 'paused' or 'over'.

--[[

#### What's on the board

We'll use an 11x20 board size. Traditional tetris games are usually 10x20, but I'm purposefully
putting in some differences in hopes of not getting sued.

The game area where pieces may live is represented by values in `board[x][y]` where
1 ≤ x ≤ `board_size.x` and 1 ≤ y ≤ `board_size.y`. The `board` variable also includes a U-shaped
border with `board[x][y] == -1` when any of the following are true:
* `x == 0`,
* `x == board_size.x + 1`, or
* `y == board_size.y + 1`.

When a shape is locked in place — that is, after it's done falling — we update the affected
cells in `board` by setting them to the shape number. This works since our shape numbers
are all > 0, so that 0 itself can represent empty cells.

It's very handy to keep the border of -1 values in the `board` itself since it simplifies
testing to see if a potential piece placement might go off the edge of the playing area.

We actually start with an empty `board` table that is filled in by the `init` function below.

The `val` variable exists so we can write code like `board[x][y] == val.border` instead
of the more cryptic `board[x][y] == -1`; and similarly for `val.empty` instead of 0.

--]]



    local board_size = {x = 11, y = 20}
    local board = {}                      -- board[x][y] = shape_num; 0=empty; -1=border.
    local val = {border = -1, empty = 0}  -- Shorthand to avoid magic numbers.


--[[

Next are the remaining globals for the `curses` library's standard screen object and
tracking the currently moving piece.

--]]

    local stdscr = nil  -- This will be the standard screen from the curses library.
    local moving_piece = {}  -- Keys will be: shape, rot_num, x, y.

--[[

---

### Function 2: Initialization

A number of things must happen before the player can start playing.
The `init` function takes care of all of these:

* Seed the random number generator.
* Expand the `shapes` table to include all shape rotations.
* Initialize the `curses` library and enable colored text rendering.
* Set up the `board` variable.
* Set up the player stats and the next and currently-moving piece.

Let's see how each of these happen.

#### Seed the random number generator

This is important since otherwise the player will see the same piece sequence every game.

--]]

    function init()
      -- Use the current time's microseconds as our random seed.
      math.randomseed(posix.gettimeofday().usec)

--[[

#### Set up the shapes table

Before this code, `shapes[shape_index][rot_num]` exists only when
`rot_num == 1`. So we have to take `shapes[shape_index][1]` and rotate it
into `shapes[shape_index][i]` for `i` = 2, 3, 4.

A simple mathematical way to perform a 90 degree rotation is to treat the point
`(x, y)` as the value rotated from `(y, -x)`. In our case, these coordinates are
table indexes, such as `shapes[shape_index][rot_num][x][y]`, so `x` and `y` are only
meaningful when they're positive integers. Instead of starting at `(y, -x)` to rotate
to `(x, y)`, we'll start at `(y, max_x + 1 - x)`. Mathematically, this is
like a rotation around `(0, 0)` followed by a translation to keep us in positive
`(x, y)` space.

This rotation method is
captured in the line `new_shape[x][y] = s[y][x_end - x]` in the loop below.

--]]

      -- Set up the shapes table.
      for s_index, s in ipairs(shapes) do
        shapes[s_index] = {}
        for rot_num = 1, 4 do
          -- Set up new_shape as s rotated by 90 degrees.
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

--[[

#### Start curses

The curses library requires initialization by calling its `initscr` function,
and by setting a number of options appropriate for a terminal-based game.
The individual comments in the code describe what each function does.

--]]

      -- Start up curses.
      curses.initscr()    -- Initialize the curses library and the terminal screen.
      curses.cbreak()     -- Turn off input line buffering.
      curses.echo(false)  -- Don't print out characters as the user types them.
      curses.nl(false)    -- Turn off special-case return/newline handling.
      curses.curs_set(0)  -- Hide the cursor.

--[[

#### Set up colors

Each piece in `termtris` has its own color. The `curses` library requires registering
an integer for each foreground/background color pair that we want to use. This is
done by calling `curses.init_pair(<my_color_index>, <fgcolor>, <bgcolor>)`; the input
colors are based on constants such as `curses.COLOR_RED`.

For clearer code, we'll use a table called `colors` to refer to the color indexes
we register with `curses.init_pair`. Later we'll define a `set_color`
function so that we can simply call `set_color(colors.red)` in order to print red
characters to the screen, for example.

--]]

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

--[[

#### Set up the standard screen object

All of our character drawing happens through this object. It is also the object
we use to make character input non-blocking, and to accept arrow keys.

--]]

      -- Set up our standard screen.
      stdscr = curses.stdscr()
      stdscr:nodelay(true)  -- Make getch nonblocking.
      stdscr:keypad()       -- Correctly catch arrow key presses.

--[[

#### Set up the board

As mentioned above, the board is mostly 0's with a U-shaped
border of -1 values along the left, right, and bottom edges.

--]]

      -- Set up the board.
      local border = {x = board_size.x + 1, y = board_size.y + 1}
      for x = 0, border.x do
        board[x] = {}
        for y = 1, border.y do
          board[x][y] = val.empty
          if x == 0 or x == border.x or y == border.y then
            board[x][y] = val.border  -- This is a border cell.
          end
        end
      end

--[[

#### Set up player stats and the next and falling pieces

We track the position, orientation, and shape number of the currently
moving piece in the `moving_piece` table. The `next_piece` table needs only
track the shape of the next piece. The `stats` table tracks lines, level, and
score; the `fall` table tracks when and how quickly the moving piece falls.

--]]

      -- Set up the next and currently moving piece.
      moving_piece = {shape = math.random(#shapes), rot_num = 1, x = 4, y = 0}

      -- Use a table so functions can edit its value without having to return it.
      next_piece = {shape = math.random(#shapes)}

      local stats = {level = 1, lines = 0, score = 0}  -- Player stats.

      -- fall.interval is the number of seconds between downward piece movements.
      local fall = {interval = 0.7}  -- A 'last_at' time is added to this table later.

--[[

#### Return local values

--]]

      return stats, fall, colors, next_piece
    end

--[[

---

### Function 3: Handling Input

Our main game loop is set up so that the `handle_input` function gets called at most once every
0.005 seconds - that is, up to 200 times each second. Most of the time, the player
will not have pressed a key between since the last time we called `handle_input`, in which
case our `stdscr:getch` call returns `nil`, and `handle_input` can return immediately.

Otherwise, we want to listen for and respond to the arrow keys and the `p` or `q` keys.
The `getch` function returns an integer key code which is a standard ascii value for conventional
keys, and a value like `curses.KEY_LEFT` for the arrow keys.

First is the code to collect the `key` value and handle quitting or pausing/unpausing.

--]]

    function handle_input(stats, fall, next_piece)
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


--[[

Next we handle the arrow keys.

Our first action is to return from `handle_input` if the
game is not in a state that responds to arrow keys — that is,
we ignore arrow keys when the game is paused or over.

After that, we can handle left, right, or up arrow keys with a simple incremental-change
table sent in to the `set_moving_piece_if_valid` function. This function will only perform
valid moves, and leaves the piece alone if the suggested move was invalid.

The down arrow action is less obvious, as we want to move the piece down as far as we can
until it hits something. A simple loop achieves this by using the return
value from `set_moving_piece_if_valid` to know when the piece has hit the bottom, at which
point it's locked in palce.

--]]

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

--[[

---

### Functions 4 and 5: Working with Pieces

The `set_moving_piece_if_valid` function accepts a table
that suggests new values for the `moving_piece`.
If those new values are valid, `moving_piece` is updated
and the function returns `true`; otherwise it returns `false`.

This function is used for all piece movements: left, right,
rotation, dropping, and even when setting up a new piece after
the previous piece has hit the bottom. A new piece may be in
an invalid position if the board has filled to the top, in which
case the game is over.

Because the board's border is included in the `board` variable,
the only check we have to make is that `board[x][y] == val.empty`
for every cell occupied by the new piece values.

We'll rely on a function called `call_fn_for_xy_in_piece` that
helpfully iterates over all `(x, y)` values occupied by
a given piece.

--]]


    -- Returns true if and only if the move was valid.
    function set_moving_piece_if_valid(piece)
      -- Use values of moving_piece as defaults.
      for k, v in pairs(moving_piece) do
        if piece[k] == nil then piece[k] = moving_piece[k] end
      end
      local is_valid = true
      call_fn_for_xy_in_piece(piece, function (x, y)
        if board[x] and board[x][y] ~= val.empty then is_valid = false end
      end)
      if is_valid then moving_piece = piece end
      return is_valid
    end

--[[

The function `call_fn_for_xy_in_piece` makes it
easy to draw the piece or check if it's in a valid location. It accepts
a callback that is called with each `(x, y)` value in the given piece.

It also accepts an optional `param` value that is passed straight through
to the callback with every call. In Lua, if you omit parameters when making a
function call, the left-out values are seen as `nil` by the function.
If you call a function with extra values set to `nil`, it is functionally the same
as if those parameters were not sent in, regardless of how many parameters a
function officially accepts. This is how `param` works as an optional parameter.

There are other ways this could have been implemented. We could have instead named this
function `piece_coords` and defined it as a Lua *iterator*. In that case,
we could have used the syntax `for x, y in piece_coords(piece) <loop body>`.
I made the subjective decision to use a callback since I would like non-Lua-experts
to find the code readable, and I consider Lua's iterator system to be less readable
to Lua newbies.

--]]

    -- This function calls callback(x, y) for each x, y coord
    -- in the given piece. Example use using draw_point(x, y):
    -- call_fn_for_xy_in_piece(moving_piece, draw_point)
    function call_fn_for_xy_in_piece(piece, callback, param)
      local s = shapes[piece.shape][piece.rot_num]
      for x, row in ipairs(s) do
        for y, val in ipairs(row) do
          if val == 1 then callback(piece.x + x, piece.y + y, param) end
        end
      end
    end


--[[

---

### Function 6: When a Piece Hits the Bottom

The next function handles everything that needs to happen when a piece hits
bottom. Once we define this function, we'll have completed all the code
that might be called - directly or indirectly - from `handle_input`.

There are three things that happen when a piece hits the bottom:

1. The moving piece becomes part of the board.
2. Any full lines are removed and scored, possibly moving us to a new level.
3. The next piece begins falling from the top of the playing area.

The code to make the moving piece part of the board is simple:

--]]


    function lock_and_update_moving_piece(stats, fall, next_piece)
      call_fn_for_xy_in_piece(moving_piece, function (x, y)
        board[x][y] = moving_piece.shape  -- Lock the moving piece in place.
      end)

--[[

Next we look for affected rows of `board` which have no empty cells;
we call these *full lines*. Each one is cleared, dropping anything above
it downward by iterating over the line `board[x][y] = board[x][y - 1]`.

We finish by incrementing the line count, the level if appropriate,
and the score.

--]]

      -- Clear any lines possibly filled up by the just-placed piece.
      local num_removed = 0
      local max_line_y = math.min(moving_piece.y + 4, board_size.y)
      for line_y = moving_piece.y + 1, max_line_y do
        local is_full_line = true
        for x = 1, board_size.x do
          if board[x][line_y] == val.empty then is_full_line = false end
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
            fall.interval = fall.interval * 0.8  -- The pieces will fall faster.
          end
          num_removed = num_removed + 1
        end
      end
      if num_removed > 0 then curses.flash() end
      stats.score = stats.score + num_removed * num_removed

--[[

Finally, `next_piece` begins to fall, and a new `next_piece` value is set up.

Even though `board[x][y]` is only valid for y ≥ 1, we want to set up new
pieces with `y=0`
because `call_fn_for_xy_in_piece`
uses the expression `piece.y + y` to determine a piece's `y` values, and
the `y` in that expression ranges from 1 up to the height of the piece.
In other words, `(moving_piece.x, moving_piece.y)` is the coordinate of the cell just
to the upper-left of where the moving piece will be drawn.

--]]

      -- Bring in the waiting next piece and set up a new next piece.
      moving_piece = {shape = next_piece.shape, rot_num = 1, x = 4, y = 0}
      if not set_moving_piece_if_valid(moving_piece) then
        game_state = 'over'
      end
      next_piece.shape = math.random(#shapes)
    end

--[[

---

### Function 7: Making Pieces Fall

The game is no fun unless the pieces fall at a reliably
constant speed that increases with the level.

If we called `sleep` or `posix.nanosleep` to wait until the
next falling moment, the piece wouldn't respond to user key
presses quickly enough. That's why the game cycle is much
faster than the fall cycle.

The fall speed is tracked by these values:

* `fall.interval` - The floating-point number of seconds between falling motions.
* `fall.last_at` - The timestamp of the last fall motion, also in floating-point seconds.

We use `posix.gettimeofday()` to get microsecond-resolution timestamps.

It's also up to the piece-falling function to do nothing if the game is over or paused,
and to call `lock_and_update_moving_piece` if the piece has hit bottom.

--]]

    function lower_piece_at_right_time(stats, fall, next_piece)
      -- This function does nothing if the game is paused or over.
      if game_state ~= 'playing' then return end

      local timeval = posix.gettimeofday()
      local timestamp = timeval.sec + timeval.usec * 1e-6
      if fall.last_at == nil then fall.last_at = timestamp end  -- Happens at startup.

      -- Do nothing until it's been fall.interval seconds since the last fall.
      if timestamp - fall.last_at < fall.interval then return end

      if not set_moving_piece_if_valid({y = moving_piece.y + 1}) then
        lock_and_update_moving_piece(stats, fall, next_piece)
      end
      fall.last_at = timestamp
    end

--[[

---

### Functions 8-10: Drawing the Screen

The last function called from `main` is `draw_screen`,
which renders the board, player stats, and next piece to
the terminal window.

Before defining `draw_screen` itself, we'll set up two
convenience functions to make drawing easier.

The first is the one-line `set_color` function, which
wraps the not-as-clearly-named `stdscr:attron` function.
The input to `stdscr:attron` is an output value from
`curses.color_pair`, which accepts the same integer
values we sent in to `curses.init_pair` back in our
`init` function. The entire purpose of `set_color`
is to clarify the act of setting a color.

--]]


    -- Accepts integer values corresponding to the 'colors' table
    -- created by init. For example, call 'set_color(colors.black)'.
    function set_color(c)
      stdscr:attron(curses.color_pair(c))
    end

--[[

The `draw_point` function essentially draws a simple
sprite on the screen. This sprite is usually a solid-color
square. A sqaure is rendered as two adjacent space characters since most
terminals draw a single space as a tall rectangle with an
aspect ratio near 1:2.

This function works with a coordinate system whose origin
is offset by a given `x_offset` column value. In this program,
`x_offset` is *always* going to be the left edge of the game
board as determined in `draw_screen`. The code is set up to
accept `x_offset` as a parameter because:

* It depends on `board_size`, and it's nice to make the rest of the
  code "just work" if `board_size` is changed.
* We can avoid a global variable by accepting
  `x_offset` as a parameter.

The last two parameters to `draw_point` are optional.
If present, the `color` parameter sets the color, and the `point_char`
parameter sets the character drawn. The only time we don't draw
space characters is when rendering the border, where we use the
'|' vertical bar character. Since `curses` only guarantees 7
non-black colors, those 7 have been used for the pieces, and the
border is rendered with a different character to visually clarify
the edge of the board.

If the game is paused and a space character is being drawn, then
`draw_piece` returns early. This way no pieces — including the
next piece — are rendered when the game is paused; the border is
still drawn.

--]]


    function draw_point(x, y, x_offset, color, point_char)
      point_char = point_char or ' '  -- Space is the default point_char.
      if color then set_color(color) end
      -- Don't draw pieces when the game is paused.
      if point_char == ' ' and game_state == 'paused' then return end
      stdscr:mvaddstr(y, x_offset + 2 * x + 0, point_char)
      stdscr:mvaddstr(y, x_offset + 2 * x + 1, point_char)
    end

--[[

The `draw_screen` function begins by erasing the screen
and recalculating the x coordinates of the left edge of the game board -
which we call the `x_margin` - and of the stats on the right
side of the board - which we call `x_labels`.
These are constantly recalculated because it's cheap to do so
and because the player may resize their terminal at any time.

It may be worth explaining this line ahead of time:

* `local win_width = 2 * (board_size.x + 2) + 16`

The `win_width` value represents the width, in characters, that
we may render to. We want it to be smaller than `scr_width`.
The `board_size.x + 2` value is the board width in cells,
plus 2 border cells; this value is converted to characters by
being doubled. The `+ 16` is meant to give 16 characters of room
in which to render the player stats and next piece. The updated
screen dimensions are illustrated here:

![](https://raw.githubusercontent.com/tylerneylon/termtris/master/img/screen_dims.png)

--]]


    function draw_screen(stats, colors, next_piece)
      stdscr:erase()

      -- Update the screen dimensions.
      local scr_width = curses.cols()
      local win_width = 2 * (board_size.x + 2) + 16
      local x_margin = math.floor((scr_width - win_width) / 2)
      local x_labels = x_margin + win_width - 10

--[[

Next we draw the board, including all previously-fallen pieces.
Because the currently-moving piece is not represented in `board`,
it's not drawn yet. The `draw_point` function avoids drawing
pieces for us if the game is paused.

--]]

      -- Draw the board's border and non-falling pieces if we're not paused.
      local color_of_val = {[val.border] = colors.text, [val.empty] = colors.black}
      local char_of_val = {[val.border] = '|'}  -- This is the border character.
      if game_state == 'over' then color_of_val[val.border] = colors.over end
      for x = 0, board_size.x + 1 do
        for y = 1, board_size.y + 1 do
          local board_val = board[x][y]
          -- Draw ' ' for shape & empty points; '|' for border points.
          local pt_char = char_of_val[board_val] or ' '
          draw_point(x, y, x_margin, color_of_val[board_val] or board_val, pt_char)
        end
      end

--[[

We either draw the string 'paused' in the middle of the board
or render the moving piece, depending on if the game state is paused
or playing.

--]]

      -- Write 'paused' if the we're paused; draw the moving piece otherwise.
      if game_state == 'paused' then
        set_color(colors.text)
        local x = x_margin + board_size.x - 1  -- Slightly left of center.
        stdscr:mvaddstr(math.floor(board_size.y / 2), x, 'paused')
      else
        set_color(moving_piece.shape)
        call_fn_for_xy_in_piece(moving_piece, draw_point, x_margin)
      end

--[[

Now we draw the player's lines, score, and level stats, along with
a *Game Over* message if the game is over.

--]]

      -- Draw the stats: level, lines, and score.
      set_color(colors.text)
      stdscr:mvaddstr( 9, x_labels, 'Level ' .. stats.level)
      stdscr:mvaddstr(11, x_labels, 'Lines ' .. stats.lines)
      stdscr:mvaddstr(13, x_labels, 'Score ' .. stats.score)
      if game_state == 'over' then
        stdscr:mvaddstr(16, x_labels, 'Game Over')
      end

--[[

Finally we render the next piece between top and bottom
lines to suggest a next piece box. The function ends with
a call to `stdscr:refresh`, which tells the `curses` library to
batch up all our drawing operations and send them to the terminal.

--]]

      -- Draw the next piece.
      stdscr:mvaddstr(2, x_labels, '----------')
      stdscr:mvaddstr(7, x_labels, '---Next---')
      local piece = {shape = next_piece.shape, rot_num = 1, x = board_size.x + 5, y = 3}
      set_color(piece.shape)
      call_fn_for_xy_in_piece(piece, draw_point, x_margin)

      stdscr:refresh()
    end

--[[

Until now, we have only defined variables and functions.
No code has been executed. It's time to call the main function!

--]]

    main()

--[[

That's the whole game.

## Learning More

If you enjoyed this, you might like further exploration of Lua and
my favorite 2D game engine, Löve, which adds modern 2D graphics capabilities
to Lua. Here are some diving boards into more
game-making goodness:

* [Of Games and Code](https://medium.com/of-games-and-code/),
  a Medium collection for game-makers
* Another shameless plug for
  [learning Lua in 15 minutes](http://tylerneylon.com/a/learn-lua/).
* The [Löve game engine home page](http://love2d.org/).
* [awesome-lua](https://github.com/LewisJEllis/awesome-lua), a curated
  list of Lua packages and resources.
* [Programming in Lua](http://www.lua.org/pil/contents.html) — an in-depth look at Lua 5.0, which
  is now a teeny bit out of date, but is well-written!
* [Mari0](http://stabyourself.net/mari0/), a combination of the original
  Super Mario Brothers plus Portal. Written in Lua + Löve.

## One More Thing

I'm working on an original large-scale game called Apanga.
If you're interested in independently-developed games, you
could [send me your email addy](http://apanga.net/) to
find out more about Apanga. I'm looking for early-stage
testers and any help/interest would be greatly appreciated!

--]]
