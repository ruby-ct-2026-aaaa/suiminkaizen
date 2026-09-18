# frozen_string_literal: true

module Kosuke
  # 平面上の座標を菱形の床へ投影する疑似3D。移動・当たり判定は平面で計算。
  class World
    WIDTH = 380
    HEIGHT = 235
    ORIGIN_X = 184
    ORIGIN_Y = 57
    TILE_X = 18
    TILE_Y = 9
    STATIONS = {
      training: { target: [2.5, 6.5], label: [1.8, 5.3], number: '1' },
      bath: { target: [3.5, 2.5], label: [1.8, 1.4], number: '2' },
      supplement: { target: [7.5, 2.5], label: [7.5, 1.4], number: '3' },
      massage: { target: [5.5, 6.5], label: [4.7, 7.3], number: '4' },
      camera: { target: [8.5, 3.5], label: [9.1, 4.3], number: '5' }
    }.freeze
    OBSTACLES = [[1, 5, 2.1, 1], [1, 1, 2, 1.5], [7, 1, 1.8, 1],
                 [7, 6, 2, 2], [0.3, 7.4, 0.7, 0.7], [4.1, 7.1, 1.5, 1.3], [8.8, 4, 0.6, 0.6]].freeze

    attr_reader :x, :y, :time, :walking, :destination

    def initialize
      @x, @y = 4.5, 4.5
      @time = 0.0
      @walking = false
      @facing = 1
      @path = []
      @destination = nil
      @background = nil
    end

    def self.project(x, y, height = 0)
      [ORIGIN_X + (x - y) * TILE_X, ORIGIN_Y + (x + y) * TILE_Y - height]
    end

    def self.unproject(sx, sy)
      a = (sx - ORIGIN_X).to_f / TILE_X
      b = (sy - ORIGIN_Y).to_f / TILE_Y
      [(a + b) / 2.0, (b - a) / 2.0]
    end

    def walkable?(x, y)
      return false unless x.between?(0.3, 9.7) && y.between?(0.3, 8.7)
      OBSTACLES.none? do |ox, oy, w, d|
        x > ox - 0.18 && x < ox + w + 0.18 && y > oy - 0.18 && y < oy + d + 0.18
      end
    end

    def go_to_station(id)
      point = STATIONS.fetch(id)[:target]
      go_to(*point)
      @destination = id
    end

    def go_to(x, y)
      @destination = nil
      goal = [x.floor.clamp(0, 9), y.floor.clamp(0, 8)]
      return false unless walkable?(goal[0] + 0.5, goal[1] + 0.5)
      start = [@x.floor, @y.floor]
      queue = [start]
      previous = { start => nil }
      until queue.empty?
        cell = queue.shift
        break if cell == goal
        [[1, 0], [-1, 0], [0, 1], [0, -1]].each do |dx, dy|
          next_cell = [cell[0] + dx, cell[1] + dy]
          next if previous.key?(next_cell)
          next unless walkable?(next_cell[0] + 0.5, next_cell[1] + 0.5)
          previous[next_cell] = cell
          queue << next_cell
        end
      end
      return false unless previous.key?(goal)
      cells = []
      cursor = goal
      while cursor
        cells.unshift([cursor[0] + 0.5, cursor[1] + 0.5])
        cursor = previous[cursor]
      end
      @path = cells
      true
    end

    def nearby
      STATIONS.keys.min_by { |id| distance(*STATIONS[id][:target]) }.then do |id|
        distance(*STATIONS[id][:target]) < 1.15 ? id : nil
      end
    end

    def distance(x, y)
      Math.hypot(@x - x, @y - y)
    end

    def stop
      @path.clear
      @destination = nil
      @walking = false
    end

    def update(dt, horizontal: 0, vertical: 0)
      @time += dt
      dx = dy = 0.0
      manual = horizontal != 0 || vertical != 0
      if manual
        stop
        dx = horizontal + vertical
        dy = vertical - horizontal
      elsif !@path.empty?
        tx, ty = @path.first
        dx, dy = tx - @x, ty - @y
        if Math.hypot(dx, dy) < 0.05
          @x, @y = @path.shift
          dx = dy = 0.0
        end
      end
      length = Math.hypot(dx, dy)
      @walking = length > 0.001
      if @walking
        step = [2.9 * dt, length].min
        nx = @x + dx / length * step
        ny = @y + dy / length * step
        @x = nx if walkable?(nx, @y)
        @y = ny if walkable?(@x, ny)
        @facing = dx - dy >= 0 ? 1 : -1
      end
      if @path.empty? && @destination
        reached = @destination
        @destination = nil
        return reached if distance(*STATIONS[reached][:target]) < 0.2
      end
      nil
    end

    def rect(x, y, w, h, color, z = 0)
      Gosu.draw_rect(x.round, y.round, w, h, color, z)
    end

    def quad(points, color, z = 0)
      args = points.flat_map { |x, y| [x.round, y.round, color] }
      Gosu.draw_quad(*args, z)
    end

    def floor_rect(x, y, w, d, color, z = 0, height = 0)
      quad([[x, y], [x + w, y], [x + w, y + d], [x, y + d]].map do |px, py|
        self.class.project(px, py, height)
      end, color, z)
    end

    def box(x, y, w, d, height, top, left, right, z, elevation = 0)
      a, b, c, e = [[x, y], [x + w, y], [x + w, y + d], [x, y + d]].map do |px, py|
        self.class.project(px, py, elevation)
      end
      at, bt, ct, et = [a, b, c, e].map { |px, py| [px, py - height] }
      quad([e, c, ct, et], left, z)
      quad([b, c, ct, bt], right, z + 0.01)
      quad([at, bt, ct, et], top, z + 0.02)
    end

    def background
      @background ||= Gosu.render(WIDTH, HEIGHT, retro: true) do
        rect(0, 0, WIDTH, HEIGHT, 0xff_182330)
        floor_rect(0.1, 0.1, 10, 9, 0xff_111a24, 0, -7)
        a = self.class.project(0, 0)
        b = self.class.project(10, 0)
        c = self.class.project(0, 9)
        quad([a, b, [b[0], b[1] - 52], [a[0], a[1] - 52]], 0xff_536d7c, 1)
        quad([a, c, [c[0], c[1] - 52], [a[0], a[1] - 52]], 0xff_829b9c, 1)
        10.times do |x|
          9.times do |y|
            color = ((x * 7 + y * 3) % 4).zero? ? 0xff_b39b81 : 0xff_bda68d
            floor_rect(x, y, 0.97, 0.97, color, 2)
          end
        end
        # 壁の縁、浴室のタイル、窓、壁掛け時計。
        floor_rect(0, 0, 10, 0.12, 0xff_273e48, 3)
        floor_rect(0, 0, 0.12, 9, 0xff_425e63, 3)
        4.times do |x|
          3.times do |y|
            floor_rect(0.2 + x * 0.8, 0.2 + y * 0.85, 0.77, 0.82, 0xff_7fb2b6, 3)
          end
        end
        wx, wy = self.class.project(5.2, 0, 41)
        quad([[wx, wy], [wx + 48, wy + 24], [wx + 48, wy + 48], [wx, wy + 24]], 0xff_283e59, 3)
        quad([[wx + 3, wy + 5], [wx + 44, wy + 25], [wx + 44, wy + 42], [wx + 3, wy + 22]], 0xff_b5becf, 3.1)
        quad([[wx + 5, wy + 18], [wx + 17, wy + 18], [wx + 30, wy + 34], [wx + 5, wy + 23]], 0xff_7b8aab, 3.2)
        rect(wx + 20, wy + 11, 2, 25, 0xff_52657b, 3.3)
        cx, cy = self.class.project(2.3, 0, 32)
        rect(cx - 7, cy - 8, 16, 18, 0xff_304452, 3)
        rect(cx - 5, cy - 6, 12, 14, 0xff_f0dcac, 3.1)
        rect(cx, cy - 3, 1, 6, 0xff_344351, 3.2)
        rect(cx, cy + 2, 4, 1, 0xff_344351, 3.2)
        floor_rect(3.4, 3.5, 2.8, 2.6, 0xff_597774, 4)
        floor_rect(3.6, 3.7, 2.4, 2.2, 0xff_6d9390, 4.1)
      end
    end

    def draw_training(z)
      floor_rect(0.7, 4.65, 2.8, 1.8, 0xff_384956, z)
      box(1.2, 5.2, 0.16, 0.6, 11, 0xff_a8b9b9, 0xff_506778, 0xff_728893, z + 0.1)
      box(2.6, 5.2, 0.16, 0.6, 11, 0xff_a8b9b9, 0xff_506778, 0xff_728893, z + 0.1)
      box(1, 5, 2.1, 0.8, 5, 0xff_d59a76, 0xff_9c5f52, 0xff_b77b62, z + 0.2, 9)
      sx, sy = self.class.project(1.5, 5.4, 23)
      rect(sx - 15, sy + 3, 35, 2, 0xff_c4d8d9, z + 0.3)
      rect(sx - 16, sy - 1, 6, 10, 0xff_263647, z + 0.4)
      rect(sx + 14, sy - 1, 6, 10, 0xff_263647, z + 0.4)
    end

    def draw_bath(z)
      box(1, 1, 2, 1.5, 12, 0xff_e4e6d9, 0xff_9bb7b5, 0xff_b9cecb, z)
      floor_rect(1.2, 1.18, 1.6, 1.15, 0xff_477c91, z + 0.1, 13)
      floor_rect(1.3, 1.3, 1.4, 0.9, 0xff_80c8cf, z + 0.2, 13)
      sx, sy = self.class.project(1.7, 1.8, 14)
      rect(sx, sy, 8, 2, 0xff_c8eff0, z + 0.3)
      rect(sx - 7, sy - 2, 4, 2, 0xff_b2e0dc, z + 0.3)
      3.times do |i|
        px, py = self.class.project(1.2 + i * 0.5, 1.4, 22 + ((@time * 3 + i * 4) % 13))
        rect(px, py, 2, 4, 0x77_d5eeee, z + 0.4)
      end
      box(0.7, 1, 0.12, 0.25, 25, 0xff_d7e0dc, 0xff_6b939c, 0xff_abc0c4, z + 0.3)
    end

    def draw_supplement(z)
      box(7, 1, 1.8, 1, 21, 0xff_c7b49d, 0xff_967f70, 0xff_a5917c, z)
      3.times do |i|
        sx, sy = self.class.project(7.25 + i * 0.5, 1.5, 21)
        colors = [0xff_8bc2b4, 0xff_c0a0d9, 0xff_ebc07d]
        rect(sx - 3, sy - 8, 6, 8, colors[i], z + 0.1)
        rect(sx - 2, sy - 10, 4, 2, 0xff_dae0d4, z + 0.2)
        rect(sx - 1, sy - 5, 2, 3, 0xff_fff0d0, z + 0.2)
      end
    end

    def draw_bed(z)
      box(7, 6, 2, 2, 9, 0xff_e6d7b9, 0xff_7b695e, 0xff_9b8474, z)
      box(7, 6, 2, 0.2, 19, 0xff_b3977c, 0xff_8d7266, 0xff_a58b79, z + 0.1)
      floor_rect(7.1, 6.2, 1.8, 0.6, 0xff_f1e7d0, z + 0.2, 10)
      box(7, 6.9, 2, 1.1, 3, 0xff_bba1c2, 0xff_7a718f, 0xff_9a88ab, z + 0.3, 9)
      floor_rect(7.1, 7, 0.18, 0.85, 0xff_d0bace, z + 0.4, 13)
    end

    def draw_massage(z)
      box(4.1, 7.1, 1.5, 1.3, 9, 0xff_c09dc3, 0xff_80587f, 0xff_987298, z)
      box(4.1, 7.1, 1.5, 0.3, 25, 0xff_e2bfdc, 0xff_80587f, 0xff_b88fb2, z + 0.1)
      box(4.1, 7.4, 0.2, 0.9, 16, 0xff_e2bfdc, 0xff_80587f, 0xff_b88fb2, z + 0.2)
      box(5.4, 7.4, 0.2, 0.9, 16, 0xff_e2bfdc, 0xff_80587f, 0xff_b88fb2, z + 0.2)
    end

    def draw_camera(z)
      sx, sy = self.class.project(9.1, 4.3)
      rect(sx - 1, sy - 26, 2, 26, 0xff_333652, z)
      rect(sx - 8, sy - 3, 18, 3, 0xff_333652, z)
      rect(sx - 10, sy - 33, 21, 13, 0xff_a69be3, z + 0.1)
      rect(sx - 7, sy - 30, 8, 7, 0xff_302e48, z + 0.2)
      rect(sx + 5, sy - 30, 3, 3, 0xff_f295be, z + 0.2)
    end

    # コードで構成した歩行用の仮ドット。提供された肖像はUIで原画像を使用。
    def draw_character(sx, sy, z, motion: @walking, facing: @facing, scale: 1)
      bob = motion ? ((Math.sin(@time * 14).abs * 2).round) : (Math.sin(@time * 2) > 0.75 ? 1 : 0)
      foot = motion ? (Math.sin(@time * 14) * 2).round : 0
      Gosu.translate(sx.round, sy.round) do
        Gosu.scale(scale) do
          rect(-8, -1, 16, 3, 0x55_132b34, z)
          rect(-6, -4 + foot, 5, 4, 0xff_d8d9ca, z + 0.1)
          rect(2, -4 - foot, 5, 4, 0xff_d8d9ca, z + 0.1)
          rect(-6, -8, 5, 5 + foot, 0xff_c17f58, z + 0.1)
          rect(2, -8, 5, 5 - foot, 0xff_c17f58, z + 0.1)
          rect(-7, -14 - bob, 15, 7, 0xff_263849, z + 0.2)
          rect(0, -11 - bob, 1, 4, 0xff_5a6975, z + 0.3)
          rect(-8, -25 - bob, 17, 13, 0xff_8c5039, z + 0.2)
          rect(-7, -24 - bob, 15, 10, 0xff_e4a06c, z + 0.3)
          rect(-5, -23 - bob, 11, 5, 0xff_f4b27d, z + 0.4)
          rect(-10, -23 - bob + foot, 4, 10, 0xff_d38d5c, z + 0.4)
          rect(7, -23 - bob - foot, 4, 10, 0xff_e2a273, z + 0.4)
          rect(-1, -18 - bob, 2, 5, 0xff_c1845c, z + 0.4)
          rect(-4, -29 - bob, 10, 6, 0xff_ce8556, z + 0.5)
          rect(-8, -39 - bob, 17, 13, 0xff_442b2b, z + 0.6)
          rect(-9, -34 - bob, 18, 9, 0xff_955339, z + 0.7)
          rect(-7, -37 - bob, 16, 12, 0xff_e6a071, z + 0.8)
          rect(-6, -35 - bob, 14, 8, 0xff_f1b77f, z + 0.9)
          rect(-8, -41 - bob, 16, 6, 0xff_422a29, z + 1)
          rect(-5, -43 - bob, 9, 4, 0xff_3c2728, z + 1)
          rect(-6, -40 - bob, 5, 3, 0xff_815348, z + 1.1)
          rect(0, -39 - bob, 6, 3, 0xff_623e37, z + 1.1)
          rect(-7, -37 - bob, 3, 5, 0xff_57362f, z + 1.1)
          eye = facing.positive? ? 1 : -3
          rect(eye - 3, -33 - bob, 4, 3, 0xff_ffedcb, z + 1.2)
          rect(eye + 4, -33 - bob, 4, 3, 0xff_ffedcb, z + 1.2)
          rect(eye - 1, -33 - bob, 2, 3, 0xff_292426, z + 1.3)
          rect(eye + 6, -33 - bob, 2, 3, 0xff_292426, z + 1.3)
          rect(eye - 3, -35 - bob, 4, 1, 0xff_57322c, z + 1.3)
          rect(eye + 4, -35 - bob, 4, 1, 0xff_57322c, z + 1.3)
          rect(eye + 1, -28 - bob, 4, 1, 0xff_744238, z + 1.3)
        end
      end
    end

    def render
      backdrop = background
      Gosu.render(WIDTH, HEIGHT, retro: true) do
        backdrop.draw(0, 0, 0)
        items = [[4.0, :bath], [9.8, :supplement], [7.6, :training], [15.0, :bed],
                 [12.5, :massage], [13.1, :camera],
                 [@x + @y, :player]]
        items.sort_by(&:first).each_with_index do |(_depth, kind), index|
          z = 10 + index * 10
          if kind == :player
            sx, sy = self.class.project(@x, @y)
            draw_character(sx, sy, z)
          else
            public_send("draw_#{kind}", z)
          end
        end
        # 鉢植えは手前。
        box(0.35, 7.5, 0.6, 0.6, 8, 0xff_d2ad8b, 0xff_937568, 0xff_b58d72, 75)
        sx, sy = self.class.project(0.65, 7.8, 12)
        rect(sx - 1, sy - 12, 2, 14, 0xff_44685a, 76)
        rect(sx - 8, sy - 10, 8, 4, 0xff_8aac7d, 76)
        rect(sx, sy - 16, 7, 5, 0xff_648d71, 76)
      end
    end
  end
end
