pieces = {
  {
    {1, 0, 0},
    {1, 1, 1}
  }
}

function pr_piece(p)
  for y = 1, #p[1] do
    for x = 1, #p do
      io.write(p[x][y])
    end
    io.write('\n')
  end
end

function rotate_piece(p)
  local new_piece = {}
  local X, Y = #p + 1, #p[1] + 1  -- Max x, y values plus 1.

  for y = 1, #p[1] do
    local row = {}
    for x = 1, #p do
      row[#row + 1] = p[x][Y - y]
    end
    new_piece[y] = row
  end

  return new_piece
end

local p = pieces[1]
for i = 1, 4 do
  pr_piece(p)
  print('')
  p = rotate_piece(p)
end
