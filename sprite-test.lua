function init()
  -- You gotta load those tasty sprites first
  blit.load_sprites("dingbads.bin")
end

function render(time)

  blit.pen(Pen(20, 30, 40))
  blit.clear()

  local ms_start = blit.now()

  --blit.alpha = 255
  --blit.mask = nullptr

  -- draw grid
  --blit.alpha = 255
  blit.pen(Pen(255, 255, 255))
  blit.rectangle(Rect(0, 0, 320, 14))

  -- Left Titles
  blit.text("Apple", minimal_font, Point(5, 20))
  blit.text("Skull", minimal_font, Point(5, 40))
  blit.text("Flowers", minimal_font, Point(5, 60))
  blit.text("Rotate", minimal_font, Point(5, 80))
  blit.text("Flip", minimal_font, Point(5, 100))

  -- Right Titles
  blit.text("Big", minimal_font, Point(85, 20))

  blit.pen(Pen(0, 0, 0))
  blit.text("Sprite demo", minimal_font, Point(5, 4))

  --local ms_start = blit.now()

  -- Left Examples

  -- Draw a sprite using its numerical index into the sprite sheet
  -- Treats the sprite sheet as a grid of 8x8 sprites numbered from 0 to 63
  -- In this case sprite number 1 is the second sprite from the top row.
  -- It should be an apple! Munch!
  blit.sprite(1, Point(50, 20))

  -- Draw a sprite using its X/Y position from the sprite sheet
  -- Treats the sprite sheet as a grid of 8x8 sprites
  -- numbered 0 to 15 across and 0 to 15 down!
  -- In this case we draw the sprite from:
  -- The 10th position across (0 based, remember!)
  -- The 3rd position down.
  -- It should be a skull! Yarr!
  blit.sprite(Point(9, 2), Point(50, 40))

  -- Draw a group of sprites starting from an X/Y position, with a width/height
  -- Treats the sprite sheet a grid of 8x8 sprites and selects a group of them defined by a Rect(x, y, w, h)
  -- The width and height are measured in sprites.
  -- In this case we draw three sprites from the 6th column on the 12th row.
  -- It should be a row of flowers! Awww!
  blit.sprite(Rect(5, 11, 3, 1), Point(50, 60))

  -- Draw a heart rotated 90, 180 and 270 degrees
  blit.pen(Pen(40, 60, 80))
  blit.rectangle(Rect(50, 80, 8, 8))
  --blit.sprite(Point(0, 4), Point(50, 80), SpriteTransform::R90)
  blit.rectangle(Rect(60, 80, 8, 8))
  --blit.sprite(Point(0, 4), Point(60, 80), SpriteTransform::R180)
  blit.rectangle(Rect(70, 80, 8, 8))
  --blit.sprite(Point(0, 4), Point(70, 80), SpriteTransform::R270)

  -- Draw a heart flipped horiontally and vertically
  blit.rectangle(Rect(50, 100, 8, 8))
  --blit.sprite(Point(0, 4), Point(50, 100), SpriteTransform::HORIZONTAL)
  blit.rectangle(Rect(60, 100, 8, 8))
  --blit.sprite(Point(0, 4), Point(60, 100), SpriteTransform::VERTICAL)
  

  -- Right examples

  -- Draw a cherry, stretched to 16x16 pixels
  --[[
  blit.stretch_blit(
    blit.sprites,
    Rect(0, 0, 8, 8),
    Rect(130, 16, 16, 16)
  )
  ]]


  local ms_end = blit.now()


  -- draw FPS meter
  --blit.alpha = 255
  blit.pen(Pen(255, 255, 255, 100))
  blit.rectangle(Rect(1, 120 - 10, 12, 9))
  blit.pen(Pen(255, 255, 255, 200))
  local fms = (ms_end - ms_start)
  blit.text(fms, minimal_font, Rect(3, 120 - 9, 10, 16))

  local block_size = 4
  for i = 0, (ms_end - ms_start) - 1 do
    blit.pen(Pen(i * 5, 255 - (i * 5), 0))
    blit.rectangle(Rect(i * (block_size + 1) + 1 + 13, 120 - block_size - 1, block_size, block_size))
  end

  blit.watermark()
end

function update(time)
end