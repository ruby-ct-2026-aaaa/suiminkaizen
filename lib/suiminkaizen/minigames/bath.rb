# frozen_string_literal: true

module Suiminkaizen
  module Minigames
    # お風呂。
    #
    # 湯温は放っておくと下がり、ゆらぎもする。上下キーで追い焚き／水を足して
    # 少しずつ動く「ちょうどいい温度」の帯に保ちつづける。
    # ただし気持ちよくなりすぎると湯船で寝落ちしかける ＝ ウトウト判定が入り、
    # SPACE で踏みとどまれなければ一気に眠気が増える。
    class Bath < Base
      MIN_TEMP = 35.0
      MAX_TEMP = 46.0

      GAUGE_X = 268
      GAUGE_Y = 52
      GAUGE_W = 18
      GAUGE_H = 128

      TUB_Z_NEAR = 3.0
      TUB_Z_FAR  = 6.4
      TUB_HALF   = 2.2
      WATER_Y    = 0.95

      class << self
        def kind  = :bath
        def title = "お風呂"
        def subtitle = "ちょうどいい湯加減をキープ"
        def theme = :bath
        def target_score = 62.0

        def controls
          ["↑ ... 追い焚き（熱くする）", "↓ ... 水を足す（ぬるくする）",
           "SPACE ... ウトウトしたら押して覚醒"]
        end

        def rules
          [
            "湯温を、ゆっくり動く緑の帯の中に保ちつづける。",
            "帯から大きく外れるとのぼせ／湯冷めで眠気が増える。",
            "リラックスが満タンになると難易度が上がり、効率も上がる。",
            "「ウトウト…」が出たら即 SPACE。湯船で寝たら致命傷。"
          ]
        end
      end

      def setup
        @temp        = 41.0
        @target      = 41.0
        @target_dir  = rand < 0.5 ? -1.0 : 1.0
        @relax       = 0.0
        @doze_timer  = 3.8 + rand * 1.6
        @doze_active = false
        @doze_left   = 0.0
        @doze_span   = 1.25
        @complain    = 0.0
        @steam       = []
        @ripple      = 0.0
        12.times { spawn_steam(rand) }
      end

      def step(dt)
        drift_temperature(dt)
        move_target(dt)
        judge(dt)
        update_doze(dt)
        update_steam(dt)
        @ripple += dt
      end

      def button_down(id)
        return unless confirm?(id)

        if @doze_active
          @doze_active = false
          @doze_timer  = 3.6 + rand * 1.8
          succeed(8.0, "しゃきっ！", Palette::CYAN, Config::W / 2, 108)
        end
      end

      def band_half
        [0.85 - (@level - 1) * 0.06, 0.34].max
      end

      private

      def drift_temperature(dt)
        # 放っておけば冷める。わずかな揺らぎもある。
        @temp -= (0.72 + @level * 0.06) * dt
        @temp += Math.sin(elapsed * 1.7) * 0.3 * dt

        @temp += 2.7 * dt if Gosu.button_down?(Gosu::KB_UP) || Gosu.button_down?(Gosu::KB_W)
        @temp -= 2.7 * dt if Gosu.button_down?(Gosu::KB_DOWN) || Gosu.button_down?(Gosu::KB_S)

        @temp = MIN_TEMP if @temp < MIN_TEMP
        @temp = MAX_TEMP if @temp > MAX_TEMP
      end

      def move_target(dt)
        speed = (0.34 + (@level - 1) * 0.06) * @difficulty
        @target += @target_dir * speed * dt
        if @target > 43.4
          @target = 43.4
          @target_dir = -1.0
        elsif @target < 39.2
          @target = 39.2
          @target_dir = 1.0
        end
      end

      def judge(dt)
        off = (@temp - @target).abs
        @complain -= dt

        if off <= band_half
          gain(1.2 * dt)
          @relax += dt * 0.12
          if @relax >= 1.0
            @relax = 0.0
            succeed(6.0, "ととのった！", Palette::AQUA, Config::W / 2, 156)
            level_up!
          end
        elsif off > band_half * 2.5
          drip(3.0 * dt)
          return unless @complain <= 0.0

          @complain = 1.5
          @combo = 0
          message = @temp > @target ? "あつい！のぼせる" : "さむい！湯冷めする"
          popup(message, Palette::RED, Config::W / 2, 156)
        end
      end

      def update_doze(dt)
        if @doze_active
          @doze_left -= dt
          return if @doze_left.positive?

          @doze_active = false
          @doze_timer  = 4.2 + rand * 1.8
          blunder(11.0, "湯船で寝落ちしかけた ＋11", Config::W / 2, 108)
          return
        end

        @doze_timer -= dt
        return if @doze_timer.positive?

        @doze_active = true
        @doze_span = [1.25 - (@level - 1) * 0.07, 0.6].max
        @doze_left = @doze_span
      end

      def spawn_steam(life = 1.0)
        @steam << { x: (rand - 0.5) * 3.6, y: WATER_Y - rand * 0.3,
                    z: TUB_Z_NEAR + rand * (TUB_Z_FAR - TUB_Z_NEAR),
                    vy: 0.22 + rand * 0.24, vz: -0.12 - rand * 0.16,
                    life: life, size: 0.18 + rand * 0.22 }
      end

      def update_steam(dt)
        heat = (@temp - MIN_TEMP) / (MAX_TEMP - MIN_TEMP)
        @steam.each do |s|
          s[:y] -= s[:vy] * dt * (0.5 + heat)
          s[:z] += s[:vz] * dt
          s[:life] -= dt * 0.28
        end
        @steam.reject! { |s| s[:life] <= 0.0 || s[:z] < 0.7 }
        spawn_steam while @steam.size < (6 + heat * 16).round
      end

      # --- 描画 -----------------------------------------------------------

      def scene_draw
        draw_tub
        draw_water
        Sprites::KOSUKE_BATH.draw3d(@camera, 0.0, WATER_Y + 0.10, 4.8, 0.95,
                                    fog: Stage.fog(:bath))
        Sprites::DUCK.draw3d(@camera, 1.45 + Math.sin(@ripple * 1.3) * 0.08,
                             WATER_Y + 0.02 + Math.sin(@ripple * 2.6) * 0.02,
                             3.7, 0.22, fog: Stage.fog(:bath))
        draw_steam
        draw_thermometer
        draw_doze_prompt if @doze_active
      end

      def draw_tub
        wall = Palette.rgb(0xd6e6e8)
        edge = Palette.rgb(0xaec8cc)
        order = Config.depth_z(TUB_Z_NEAR) + 4

        # 手前の側面
        tl = @camera.project(-TUB_HALF, WATER_Y - 0.22, TUB_Z_NEAR)
        tr = @camera.project(TUB_HALF, WATER_Y - 0.22, TUB_Z_NEAR)
        bl = @camera.project(-TUB_HALF, Stage::FLOOR_Y, TUB_Z_NEAR)
        br = @camera.project(TUB_HALF, Stage::FLOOR_Y, TUB_Z_NEAR)
        Px.quad(tl[0], tl[1], tr[0], tr[1], bl[0], bl[1], br[0], br[1],
                wall, wall, edge, edge, order)

        # 縁（手前から奥へ伸びる天面）
        [[-TUB_HALF, -1], [TUB_HALF, 1]].each do |(x, dir)|
          a = @camera.project(x, WATER_Y - 0.22, TUB_Z_NEAR)
          b = @camera.project(x, WATER_Y - 0.22, TUB_Z_FAR)
          c = @camera.project(x + dir * 0.22, WATER_Y - 0.22, TUB_Z_NEAR)
          d = @camera.project(x + dir * 0.22, WATER_Y - 0.22, TUB_Z_FAR)
          Px.quad(a[0], a[1], b[0], b[1], c[0], c[1], d[0], d[1],
                  wall, edge, wall, edge, order - 1)
        end
      end

      def draw_water
        heat  = ((@temp - 38.0) / 6.0).clamp(0.0, 1.0)
        near  = Palette.mix(Palette.rgb(0x63b9d4), Palette.rgb(0xe07a6a), heat)
        far   = Palette.mix(near, Stage.fog(:bath), 0.45)
        order = Config.depth_z(TUB_Z_NEAR) + 2

        fl = @camera.project(-TUB_HALF + 0.05, WATER_Y, TUB_Z_FAR)
        fr = @camera.project(TUB_HALF - 0.05, WATER_Y, TUB_Z_FAR)
        nl = @camera.project(-TUB_HALF + 0.05, WATER_Y, TUB_Z_NEAR)
        nr = @camera.project(TUB_HALF - 0.05, WATER_Y, TUB_Z_NEAR)
        Px.quad(fl[0], fl[1], fr[0], fr[1], nl[0], nl[1], nr[0], nr[1],
                far, far, near, near, order)

        # 波紋
        4.times do |i|
          z = TUB_Z_NEAR + 0.4 + i * 0.85 + Math.sin(@ripple * 1.6 + i) * 0.12
          a = @camera.project(-TUB_HALF + 0.3, WATER_Y, z)
          b = @camera.project(TUB_HALF - 0.3, WATER_Y, z)
          Px.rect(a[0], a[1], b[0] - a[0], 1,
                  Palette.alpha(Palette::WHITE, 60), order + 1)
        end
      end

      def draw_steam
        @steam.each do |s|
          alpha = (110 * [s[:life], 1.0].min).round
          next if alpha <= 4

          Sprites::STEAM.draw3d(@camera, s[:x], s[:y], s[:z], s[:size],
                                palette: { "A" => Palette.alpha(Palette::WHITE, alpha) })
        end
      end

      def draw_thermometer
        z = 160
        Px.rect(GAUGE_X - 4, GAUGE_Y - 14, GAUGE_W + 8, GAUGE_H + 30, Palette::INK, z)
        Px.rect(GAUGE_X, GAUGE_Y, GAUGE_W, GAUGE_H, Palette.rgb(0x22384a), z + 1)

        # ちょうどいい帯
        band_top = temp_to_y(@target + band_half)
        band_bottom = temp_to_y(@target - band_half)
        Px.rect(GAUGE_X, band_top, GAUGE_W, band_bottom - band_top,
                Palette.alpha(Palette::GREEN, 190), z + 2)
        Px.rect(GAUGE_X - 4, temp_to_y(@target) - 1, GAUGE_W + 8, 1,
                Palette.alpha(Palette::WHITE, 120), z + 3)

        # 現在の湯温
        y = temp_to_y(@temp)
        heat = ((@temp - 38.0) / 6.0).clamp(0.0, 1.0)
        Px.rect(GAUGE_X, y, GAUGE_W, GAUGE_Y + GAUGE_H - y,
                Palette.mix(Palette::AQUA, Palette::RED, heat), z + 4)
        Px.rect(GAUGE_X - 3, y - 1, GAUGE_W + 6, 3, Palette::WHITE, z + 5)

        Px.text_shadow(Assets.tiny, format("%.1f度", @temp), GAUGE_X + GAUGE_W / 2,
                       GAUGE_Y + GAUGE_H + 4, Palette::WHITE, z + 6, align: :center)
        Px.text_shadow(Assets.tiny, "湯温", GAUGE_X + GAUGE_W / 2, GAUGE_Y - 13,
                       Palette::BONE, z + 6, align: :center)

        # リラックスゲージ
        Px.rect(GAUGE_X - 14, GAUGE_Y, 8, GAUGE_H, Palette.rgb(0x22384a), z + 1)
        fill = (GAUGE_H * @relax).round
        Px.rect(GAUGE_X - 14, GAUGE_Y + GAUGE_H - fill, 8, fill, Palette::PINK, z + 2)
      end

      def temp_to_y(temp)
        t = ((temp - MIN_TEMP) / (MAX_TEMP - MIN_TEMP)).clamp(0.0, 1.0)
        GAUGE_Y + GAUGE_H - GAUGE_H * t
      end

      def draw_doze_prompt
        ratio = @doze_left / @doze_span
        Px.rect(0, 96, Config::W, 34, Palette.alpha(Palette::INK, 190), 180)
        Px.text_shadow(Assets.large, "ウトウト…", Config::W / 2, 100,
                       Palette::RED, 181, align: :center)
        width = (200 * ratio).round
        Px.rect(Config::W / 2 - 100, 124, 200, 4, Palette.rgb(0x3a2244), 181)
        Px.rect(Config::W / 2 - 100, 124, width, 4, Palette::YELLOW, 182)
        Px.text_shadow(Assets.small, "SPACE ！", Config::W / 2, 132,
                       Palette::WHITE, 182, align: :center)
      end
    end
  end
end
