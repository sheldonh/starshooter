#!/usr/bin/env ruby

require "gosu"

module Screen
  WIDTH = 1152
  HEIGHT = 648
end

module ZOrder
  BACKGROUND = 0
  # STARFIELD = 2,4,6,...,20
  ASTEROID = 13
  PLAYER = 15
  EXPLOSION = 17
  TEXT = 19
end

class Game < Gosu::Window

  TOTAL_ASTEROIDS = 60
  INITIAL_ASTEROIDS = 10
  WIN_ASTEROIDS = TOTAL_ASTEROIDS - INITIAL_ASTEROIDS

  def initialize
    @width = Screen::WIDTH
    @height = Screen::HEIGHT
    super(@width, @height, fullscreen: true)
    self.caption = "Starshooter"
    @stars = Array.new(20)  { Star.new(rand(@width), rand(@height), rand(10) + 1) }
    @extra_asteroids = Array.new(TOTAL_ASTEROIDS) { Asteroid.new(@width * 2 + rand(@width), rand(@height), rand(10) + 1) }
    @asteroids = @extra_asteroids.pop(INITIAL_ASTEROIDS)
    @player = Player.new(64, @height / 2)
    @message = Gosu::Font.new(128)
    @help = Gosu::Font.new(32)
    @scoreboard = Gosu::Font.new(32, name: "courier")
    @explosion = Gosu::Sample.new("assets/explosion.wav").tap { |x| x.play(0) }
    @score_up = Gosu::Sample.new("assets/score-up.wav").tap { |x| x.play(0) }
    @win = Gosu::Sample.new("assets/win.wav").tap { |x| x.play(0) }
    @paused = true
    @game_over = false
    @game_won = false
    @score = 0
  end

  def update
    unless @paused
      unless @game_over or @game_won
        @player.update
        @asteroids.each do |asteroid|
          asteroid.update
          if asteroid.x + asteroid.width < 0
            asteroid.warp(@width + rand(@width), rand(@height), rand(10) + 1)
            @score += 1
            if @score % 10 == 0
              if @extra_asteroids.empty?
                @score_up.play
                @win.play
                @game_won = true
                break
              else
                @score_up.play
                @asteroids << @extra_asteroids.pop
              end
            end
          elsif asteroid.y + asteroid.height < 0 or asteroid.y > @height
            asteroid.warp(@width + rand(@width), rand(@height), rand(10) + 1)
          elsif @player.collide?(asteroid)
            @game_over = true
            @explosion.play
            break
          end
        end
      end

      @stars.each do |star|
        star.move
        if star.x + star.width < 0
          star.warp(@width, rand(@height), rand(10) + 1)
        end
      end
    end
  end

  def button_up(id)
    case id
    when Gosu::KB_ESCAPE
      close
    when Gosu::KB_SPACE
      if @game_over or @game_won
        reset
      else
        @paused = !@paused
      end
    else
      super
    end
  end

  def draw
    if @game_over
      @message.draw("GAME OVER", @width / 2 - @message.text_width("GAME OVER") / 2, @height / 2 - @message.height / 2, ZOrder::TEXT)
      @help.draw("PRESS SPACE TO PLAY AGAIN", @width / 2 - @help.text_width("PRESS SPACE TO PLAY AGAIN") / 2, @height / 2 + @message.height, ZOrder::TEXT)
    end
    if @game_won
      @message.draw("YOU WON", @width / 2 - @message.text_width("YOU WON") / 2, @height / 2 - @message.height / 2, ZOrder::TEXT)
      @help.draw("PRESS SPACE TO PLAY AGAIN", @width / 2 - @help.text_width("PRESS SPACE TO PLAY AGAIN") / 2, @height / 2 + @message.height, ZOrder::TEXT)
    end
    if @paused
      @help.draw("PRESS SPACE TO UNPAUSE", @width / 2 - @help.text_width("PRESS SPACE TO UNPAUSE") / 2, @height / 2 + @message.height, ZOrder::TEXT)
    end

    @stars.each { |star| star.draw }
    @asteroids.each { |asteroid| asteroid.draw }
    @player.draw
    scoreboard_message = "#{WIN_ASTEROIDS - @extra_asteroids.size} / #{WIN_ASTEROIDS}"
    @scoreboard.draw(scoreboard_message, @width - @scoreboard.text_width(scoreboard_message) - @scoreboard.height, @height - @scoreboard.height, ZOrder::TEXT)
  end

  def reset
    @extra_asteroids.concat(@asteroids)
    @asteroids.clear
    @asteroids.concat(@extra_asteroids.pop(INITIAL_ASTEROIDS))
    @asteroids.each do |asteroid|
      asteroid.warp(@width * 2 + rand(@width), rand(@height), rand(10) + 1)
    end
    @player.reset
    @game_over = false
    @game_won = false
    @score = 0
  end

end

class Player

  MAX_V_Y = 4
  COLLISION_DISTANCE = 20

  attr_reader :x, :y, :width, :height

  def initialize(x, y)
    @x = x
    @y = y
    @images = [Gosu::Image.new("assets/starshooter-up.png"),
               Gosu::Image.new("assets/starshooter-steady.png"),
               Gosu::Image.new("assets/starshooter-down.png")]
    @explosions = Gosu::Image.load_tiles("assets/explosion-tiles.png", 128, 128)
    @width = 80
    @height = 80
    reset
  end

  def update
    if Gosu.button_down?(Gosu::KB_UP) or Gosu.button_down?(Gosu::KB_Q)
      @v_y -= 3
      @v_y = -MAX_V_Y if @v_y < MAX_V_Y
    elsif Gosu.button_down?(Gosu::KB_DOWN) or Gosu.button_down?(Gosu::KB_A)
      @v_y += 3
      @v_y = MAX_V_Y if @v_y > MAX_V_Y
    end

    @y += @v_y
    if @y < 0
      @y = 0
    elsif @y + @height > Screen::HEIGHT
      @y = Screen::HEIGHT - @height
    end
    @v_y += -1 * (@v_y <=> 0)
  end

  def draw
    unless @exploded
      @images[(@v_y <=> 0) + 1].draw(@x, @y, ZOrder::PLAYER)
    end
    if @exploding
      frame_speed = 3
      frame = @exploding / frame_speed
      if frame > @explosions.size - 1
        @exploding = nil
      else
        @explosions[frame].draw(@x - 40, @y - 40, ZOrder::EXPLOSION, 1.250, 1.250)
        @exploded = true if frame > (@explosions.size - 1) / 2
        @exploding += 1
      end
    end
  end

  def collide?(o)
    if Gosu.distance(@x + @width / 2, @y + @height / 2, o.x + o.width / 2, o.y + o.height / 2) < COLLISION_DISTANCE
      @exploding = 0
    end
  end

  def reset
    @v_y = 0
    @v_x = 0
    @exploding = nil
    @exploded = nil
  end

end

class Asteroid

  attr_reader :x, :y, :v, :width, :height

  def initialize(x, y, v)
    warp(x, y, v)
    @img = Gosu::Image.new("assets/asteroid.png")
    @rot = rand(360)
    @spin = (rand(10) + 5) * (rand(2) > 0 ? 1 : -1)
    @width = @img.width
    @height = @img.height
  end

  def update
    @x -= @v + 5
    @y += @v_y
    @rot += @spin
  end

  def warp(x, y, v)
    @x = x
    @y = y
    @v = v
    @v_y = rand(100) < 80 ? 0 : (rand(21) - 10) / 10.0
  end

  def draw
    @img.draw_rot(@x + @width / 2, @y + @width / 2, ZOrder::ASTEROID, @rot)
  end

end

class Star

  attr_reader :x, :y, :scale, :width

  def initialize(x, y, scale_int)
    @color = Gosu::Color.new(0xFF_FFFFFF)
    warp(x, y, scale_int)
    @img = Gosu::Image.new("assets/star.png")
    @width = @scale_int / 10.0 * @img.width
  end

  def move
    @x -= @scale_int
    @color.alpha += @blink * @scale_int * 2
    if @color.alpha < 1
      @color.alpha = 0
      @blink = 1
    elsif @color.alpha > 4 * (255 / @scale_int)
      @color.alpha = 4 * (255 / @scale_int)
      @blink = -1
    end
  end

  def warp(x, y, scale_int)
    @x = x
    @y = y
    @scale_int = scale_int
    @color.alpha = rand(128) + 1
    @blink = -1
  end

  def draw
    @img.draw(@x, @y, @scale_int * 2, 2 * @scale_int / 10.0, 2 * @scale_int / 10.0, @color)
  end

end

Game.new.show
