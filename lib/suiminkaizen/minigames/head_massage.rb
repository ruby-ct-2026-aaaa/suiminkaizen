# frozen_string_literal: true

module Suiminkaizen
  module Minigames
    # ヘッドマッサージ（乱入イベント）。
    #
    # 1日に2回、ヘッドマッサージ師が前触れもなく現れて頭を揉みはじめる。
    # 断ることはできない。指が動くたびに「気持ちよさ」が溜まっていき、
    # 満タンになるといびきをかいて一気に眠気が増す。
    #
    # ときどき出る矢印を、指が止まっているあいだに正しく押し返すことで
    # 気持ちよさを押し下げる。押し間違いと押し遅れはどちらも命取り。
    class HeadMassage < Base
      KOSUKE_Z = 3.9

      KEYS = {
        Gosu::KB_LEFT  => "←",
        Gosu::KB_UP    => "↑",
        Gosu::KB_RIGHT => "→",
        Gosu::KB_DOWN  => "↓"
      }.freeze

      SPOTS = ["こめかみ", "後頭部", "首すじ", "頭頂部", "耳のうしろ"].freeze

      BAR_X = 60
      BAR_W = 200
      BAR_Y = 176
      BAR_H = 14

      class << self
        def kind  = :massage
        def title = "ヘッドマッサージ"
        def subtitle = "乱入！ いびきをかいたら終わり"
        def theme = :salon
        def target_score = 65.0

        def controls
          ["← ↑ → ↓ ... 表示された矢印を押して耐える"]
        end

        def rules
          [
            "マッサージ師が乱入。断れないので耐えるしかない。",
            "指が動くたび「気持ちよさ」が溜まっていく。",
            "矢印が出たら、その向きのキーを時間内に押し返す。",
            "満タンになるといびき ＝ 眠気が一気に増える。"
          ]
        end
      end

      def setup
        @bliss        = 0.18
        @prompt       = nil
        @prompt_timer = 1.0
        @answered     = 0
        @snore        = 0.0
        @spot         = SPOTS.sample
        @knead        = 0.0
      end

      def step(dt)
        @knead += dt * (5.0 + @bliss * 4.0)
        @snore -= dt
        @snore = 0.0 if @snore.negative?

        soak(dt)
        update_prompt(dt)
      end

      def button_down(id)
        return unless KEYS.key?(id)
        return unless @prompt

        if id == @prompt[:key]
          @answered += 1
          @bliss = [@bliss - 0.18, 0.0].max
          succeed(3.0, "こらえた！", Palette::CYAN, Config::W / 2, 122)
          @prompt = nil
          @prompt_timer = interval
          level_up! if (@answered % 5).zero?
        else
          @prompt = nil
          @prompt_timer = interval
          @bliss = [@bliss + 0.10, 1.0].min
          blunder(14.0, "押し間違えた ＋14", Config::W / 2, 122)
        end
      end

      def bliss = @bliss

      private

      # 気持ちよさは放っておけば溜まる一方。満タンでいびき。
      def soak(dt)
        rate = (0.105 + (@level - 1) * 0.012) * @difficulty
        @bliss += rate * dt
        return if @bliss < 1.0

        @bliss = 0.45
        @snore = 1.4
        @spot  = SPOTS.sample
        @camera.kick(0.8)
        blunder(30.0, "グー…… いびきをかいた ＋30", Config::W / 2, 104)
      end

      def interval
        [(1.55 - (@level - 1) * 0.12) / @difficulty, 0.65].max * (0.85 + rand * 0.3)
      end

      def answer_window
        [(1.30 - (@level - 1) * 0.08) / @difficulty, 0.55].max
      end

      def update_prompt(dt)
        if @prompt
          @prompt[:left] -= dt
          return if @prompt[:left].positive?

          @prompt = nil
          @prompt_timer = interval
          @bliss = [@bliss + 0.12, 1.0].min
          blunder(14.0, "力が抜けた ＋14", Config::W / 2, 122)
          return
        end

        @prompt_timer -= dt
        return if @prompt_timer.positive?

        key = KEYS.keys.sample
        span = answer_window
        @prompt = { key: key, symbol: KEYS[key], left: span, span: span }
        @spot = SPOTS.sample
      end

      # --- 描画 -----------------------------------------------------------

      def scene_draw
        draw_chair
        draw_kosuke
        draw_masseur
        draw_bliss_meter
        draw_prompt if @prompt
        draw_snore if @snore.positive?
      end

      def draw_chair
        scale = @camera.scale_at(KOSUKE_Z)
        seat  = @camera.project(0.0, Stage::FLOOR_Y, KOSUKE_Z)
        Px.rect(seat[0] - 0.62 * scale, seat[1] - 0.72 * scale,
                1.24 * scale, 0.72 * scale, Palette.rgb(0x6d4f3c),
                Config.depth_z(KOSUKE_Z) - 1)
        Px.rect(seat[0] - 0.68 * scale, seat[1] - 0.78 * scale,
                1.36 * scale, 0.1 * scale, Palette.rgb(0x8a6750),
                Config.depth_z(KOSUKE_Z) - 0.5)
      end

      def draw_kosuke
        sprite = @snore.positive? ? Assets.portrait(:sleep) : Assets.portrait(:normal)
        if sprite
          bottom = Stage::FLOOR_Y - 0.62
          height = @snore.positive? ? 0.62 : 1.02
          sprite.draw3d(@camera, 0.0, bottom, KOSUKE_Z, height, fog: Stage.fog(:salon))
        else
          Sprites::KOSUKE.draw3d(@camera, 0.0, Stage::FLOOR_Y - 0.6, KOSUKE_Z, 1.0,
                                 fog: Stage.fog(:salon))
        end
      end

      HEAD_Y    = Stage::FLOOR_Y - 1.42 # 峰小輔の頭の高さ（立ち絵に合わせた値）
      MASSEUR_Z = KOSUKE_Z + 0.5

      # 世界座標の2点を結ぶ「手足」。端で太さを変えられるので腕らしく見える。
      def limb(x0, y0, z0, x1, y1, z1, half0, half1, color, order)
        a = @camera.project(x0, y0, z0)
        b = @camera.project(x1, y1, z1)
        dx = b[0] - a[0]
        dy = b[1] - a[1]
        length = Math.hypot(dx, dy)
        return if length < 0.01

        nx = -dy / length
        ny = dx / length
        w0 = half0 * a[2]
        w1 = half1 * b[2]
        Px.quad(a[0] + nx * w0, a[1] + ny * w0, a[0] - nx * w0, a[1] - ny * w0,
                b[0] + nx * w1, b[1] + ny * w1, b[0] - nx * w1, b[1] - ny * w1,
                color, color, color, color, order)
      end

      # マッサージ師は椅子の後ろに立っている。
      # 峰小輔に隠れてほとんど見えないので、頭の上に出る部分と、
      # 頭へ下りてくる腕だけをはっきり描く。
      def draw_masseur
        order = Config.depth_z(MASSEUR_Z)
        coat  = Palette.rgb(0x6f5c7d)

        plate = lambda do |x0, y0, x1, y1, color, zz|
          a = @camera.project(x0, y0, MASSEUR_Z)
          b = @camera.project(x1, y1, MASSEUR_Z)
          Px.rect(a[0], a[1], b[0] - a[0], b[1] - a[1], color, zz)
        end

        # 肩から上（峰小輔の頭より高い位置に出る）
        plate.call(-0.52, Stage::FLOOR_Y - 1.95, 0.52, Stage::FLOOR_Y - 0.4, coat, order)
        plate.call(-0.52, Stage::FLOOR_Y - 1.95, 0.52, Stage::FLOOR_Y - 1.88,
                   Palette.rgb(0x8a7699), order + 1)
        plate.call(-0.09, Stage::FLOOR_Y - 2.10, 0.09, Stage::FLOOR_Y - 1.95,
                   Palette::SKIN_DARK, order + 1)
        plate.call(-0.20, Stage::FLOOR_Y - 2.48, 0.20, Stage::FLOOR_Y - 2.10,
                   Palette::SKIN, order + 1)
        plate.call(-0.22, Stage::FLOOR_Y - 2.56, 0.22, Stage::FLOOR_Y - 2.34,
                   Palette.rgb(0x3d3145), order + 2)

        draw_arms(order)
      end

      # 頭を揉む腕と手。左右で位相をずらして、こねるように動かす。
      def draw_arms(order)
        hand_z = KOSUKE_Z - 0.14
        hand_scale = @camera.scale_at(hand_z)
        hand_order = Config.depth_z(hand_z)

        [[-1, 0.0], [1, Math::PI * 0.6]].each do |(side, phase)|
          wobble = Math.sin(@knead + phase) * 0.035
          bob    = Math.cos(@knead * 1.3 + phase) * 0.03
          cx = side * (0.22 + wobble)
          cy = HEAD_Y + bob

          # 肩 → ひじ → 手首。袖は白衣、そこから先は素肌。
          elbow_x = side * 0.46
          elbow_y = Stage::FLOOR_Y - 1.80
          limb(side * 0.44, Stage::FLOOR_Y - 1.86, MASSEUR_Z,
               elbow_x, elbow_y, MASSEUR_Z - 0.2, 0.10, 0.085,
               Palette.rgb(0xe8dfef), order + 3)
          limb(elbow_x, elbow_y, MASSEUR_Z - 0.2,
               cx + side * 0.06, cy - 0.06, hand_z, 0.08, 0.065,
               Palette::SKIN_DARK, hand_order - 1)

          # 手のひらと指
          a = @camera.project(cx - 0.09, cy - 0.13, hand_z)
          b = @camera.project(cx + 0.09, cy + 0.08, hand_z)
          Px.rect(a[0], a[1], b[0] - a[0], b[1] - a[1], Palette::SKIN, hand_order)
          3.times do |i|
            fx = cx - 0.06 + i * 0.06
            f0 = @camera.project(fx - 0.018, cy + 0.04, hand_z)
            f1 = @camera.project(fx + 0.018, cy + 0.15, hand_z)
            Px.rect(f0[0], f0[1], f1[0] - f0[0], f1[1] - f0[1],
                    Palette::SKIN, hand_order + 1)
          end
          Px.rect(a[0], a[1], b[0] - a[0], [(0.035 * hand_scale).round, 1].max,
                  Palette.mix(Palette::SKIN, Palette::WHITE, 0.45), hand_order + 2)
        end
      end

      def draw_bliss_meter
        z = 150
        Px.rect(BAR_X - 3, BAR_Y - 3, BAR_W + 6, BAR_H + 6, Palette::INK, z)
        Px.rect(BAR_X, BAR_Y, BAR_W, BAR_H, Palette.rgb(0x3a2b46), z + 1)

        # 終盤は赤い危険域
        danger = (BAR_W * 0.75).round
        Px.rect(BAR_X + danger, BAR_Y, BAR_W - danger, BAR_H,
                Palette.alpha(Palette::RED, 70), z + 2)

        fill = (BAR_W * @bliss).round
        tone = Palette.mix(Palette::PINK, Palette::RED, [(@bliss - 0.5) * 2, 0.0].max)
        Px.rect(BAR_X, BAR_Y, fill, BAR_H, tone, z + 3)
        Px.rect(BAR_X, BAR_Y, fill, 2, Palette.mix(tone, Palette::WHITE, 0.5), z + 4)

        Px.text_shadow(Assets.tiny, "気持ちよさ", BAR_X, BAR_Y - 15, Palette::BONE, z + 5)
        Px.text_shadow(Assets.tiny, @spot, BAR_X + BAR_W, BAR_Y - 15,
                       Palette::PINK, z + 5, align: :right)
      end

      def draw_prompt
        ratio = @prompt[:left] / @prompt[:span]
        Px.rect(Config::W / 2 - 46, 96, 92, 50, Palette.alpha(Palette::INK, 205), 180)
        Px.frame(Config::W / 2 - 46, 96, 92, 50, Palette::CYAN, 181)
        Px.text_shadow(Assets.title, @prompt[:symbol], Config::W / 2, 92,
                       Palette::WHITE, 182, align: :center)

        width = (80 * ratio).round
        Px.rect(Config::W / 2 - 40, 138, 80, 4, Palette.rgb(0x3a2244), 182)
        Px.rect(Config::W / 2 - 40, 138, width,  4,
                ratio < 0.35 ? Palette::RED : Palette::YELLOW, 183)
      end

      def draw_snore
        alpha = (255 * [@snore / 1.4, 1.0].min).round
        Px.text_shadow(Assets.huge, "グ ー …", Config::W / 2, 66,
                       Palette.alpha(Palette::RED, alpha), 185, align: :center)
        3.times do |i|
          Px.text_shadow(Assets.large, "Z", 196 + i * 14, 92 - i * 12,
                         Palette.alpha(Palette::AQUA, alpha), 185)
        end
      end
    end
  end
end
