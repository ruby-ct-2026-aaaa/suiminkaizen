# frozen_string_literal: true

module Suiminkaizen
  module Minigames
    # ヘッドマッサージ（乱入イベント）。
    #
    # 1日に2回、ヘッドマッサージ師が前触れもなく現れて頭を揉みはじめる。
    # 断ることはできない。指が動くたびに「気持ちよさ」が溜まっていき、
    # 満タンになるといびきをかいて一気に眠気が増す。
    #
    # ときどき出る指示を、指が止まっているあいだに正しく押し返すことで
    # 気持ちよさを押し下げる。押し間違いと押し遅れはどちらも命取り。
    #
    # 指示は1手ではなく「← ↑ SP」のような手順になっていて、
    # レベルが上がるほど手数が伸びる。順番どおりに最後まで入れきること。
    class HeadMassage < Base
      KOSUKE_Z = 3.9

      KEYS = {
        Gosu::KB_LEFT  => "←",
        Gosu::KB_UP    => "↑",
        Gosu::KB_RIGHT => "→",
        Gosu::KB_DOWN  => "↓",
        Gosu::KB_SPACE => "SP"
      }.freeze

      # 手順の最大の長さ。
      MAX_STEPS = 3

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
        def target_score = 46.0

        def controls
          ["← ↑ → ↓ と SPACE ... 表示された手順を左から順に押す"]
        end

        def rules
          [
            "マッサージ師が乱入。断れないので耐えるしかない。",
            "指が動くたび「気持ちよさ」が溜まっていく。",
            "出てくる手順（例：← SP ↓）を、順番どおり時間内に押しきる。",
            "1つでも間違えるとやり直しはなし。満タンでいびき ＝ 大ダメージ。"
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

      # 乱入の瞬間に警報。断れないことを音でも知らせる。
      def enter
        Sound.play(:alarm)
      end

      def step(dt)
        @knead += dt * (5.0 + @bliss * 4.0)
        @snore -= dt
        @snore = 0.0 if @snore.negative?

        soak(dt)
        update_prompt(dt)
      end

      def button_down(id)
        super
        return unless KEYS.key?(id)
        return unless @prompt

        if id == @prompt[:keys][@prompt[:index]]
          advance_prompt
        else
          @prompt = nil
          @prompt_timer = interval
          @bliss = [@bliss + 0.10, 1.0].min
          blunder(14.0, "押し間違えた ＋14", Config::W / 2, 122)
        end
      end

      def bliss = @bliss
      def prompt = @prompt

      private

      # 手順を1つ進める。最後まで入れきれたら気持ちよさを押し下げられる。
      def advance_prompt
        @prompt[:index] += 1
        steps = @prompt[:keys].size
        if @prompt[:index] < steps
          popup("#{@prompt[:index]} / #{steps}", Palette::BONE, Config::W / 2, 146)
          return
        end

        @answered += 1
        # 長い手順ほど、こらえたときの効きが大きい。
        @bliss = [@bliss - (0.12 + steps * 0.06), 0.0].max
        succeed(1.6 + steps * 1.4, "こらえた！", Palette::CYAN, Config::W / 2, 122)
        @prompt = nil
        @prompt_timer = interval
        level_up! if (@answered % 5).zero?
      end

      # レベルが上がるほど手数が伸びる。
      def steps_for_level
        [1 + (@level - 1) / 3, MAX_STEPS].min
      end

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

      def answer_window(steps = 1)
        base = [(1.30 - (@level - 1) * 0.08) / @difficulty, 0.55].max
        base * (1.0 + (steps - 1) * 0.72)
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

        steps = steps_for_level
        keys  = Array.new(steps) { KEYS.keys.sample }
        span  = answer_window(steps)
        @prompt = { keys: keys, symbols: keys.map { |k| KEYS[k] },
                    index: 0, left: span, span: span }
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
      # 峰小輔の背中に隠れるので、見えるのは肩から上と、
      # 頭へ下りてくる腕だけ。そこをドット絵で描く。
      MASSEUR_HEIGHT = 1.85 # 肩から上が、ちょうど峰小輔の頭の上に出る大きさ
      MASSEUR_BOTTOM = 0.55 # 床からどれだけ浮かせて描くか（腰から下は見えない）

      def draw_masseur
        order = Config.depth_z(MASSEUR_Z)

        # 揉むたびに、ほんのわずか上体が動く。
        sway = Math.sin(@knead * 0.5) * 0.02
        Sprites::MASSEUR.draw3d(@camera, sway, Stage::FLOOR_Y - MASSEUR_BOTTOM,
                                MASSEUR_Z, MASSEUR_HEIGHT, fog: Stage.fog(:salon))

        draw_arms(order)
      end

      # 頭を揉む腕と手。左右で位相をずらして、こねるように動かす。
      def draw_arms(order)
        hand_z = KOSUKE_Z - 0.14
        hand_order = Config.depth_z(hand_z)

        [[-1, 0.0], [1, Math::PI * 0.6]].each do |(side, phase)|
          wobble = Math.sin(@knead + phase) * 0.035
          bob    = Math.cos(@knead * 1.3 + phase) * 0.03
          cx = side * (0.22 + wobble)
          cy = HEAD_Y + bob

          # 肩 → ひじ → 手首。袖は白衣、そこから先は素肌。
          elbow_x = side * 0.50
          elbow_y = Stage::FLOOR_Y - 1.72
          limb(side * 0.40, Stage::FLOOR_Y - 1.80, MASSEUR_Z,
               elbow_x, elbow_y, MASSEUR_Z - 0.2, 0.085, 0.07,
               Palette.rgb(0xe8dfef), order + 3)
          limb(elbow_x, elbow_y, MASSEUR_Z - 0.2,
               cx + side * 0.05, cy - 0.04, hand_z, 0.065, 0.05,
               Palette::SKIN_DARK, hand_order - 1)

          # 手はドット絵。内向きになるよう、左右で反転させる。
          Sprites::HAND.draw3d(@camera, cx, cy + 0.14, hand_z, 0.30,
                               flip: side.negative?, z: hand_order + 1,
                               fog: Stage.fog(:salon))
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

      # 手順を左から並べ、済んだものは沈ませ、次に押すものだけを光らせる。
      def draw_prompt
        ratio  = @prompt[:left] / @prompt[:span]
        steps  = @prompt[:symbols].size
        cell   = 46
        width  = cell * steps + 12
        left   = Config::W / 2 - width / 2

        Px.rect(left, 96, width, 50, Palette.alpha(Palette::INK, 205), 180)
        Px.frame(left, 96, width, 50, Palette::CYAN, 181)

        @prompt[:symbols].each_with_index do |symbol, i|
          x = left + 6 + cell * i + cell / 2
          tone =
            if i < @prompt[:index] then Palette::SLATE
            elsif i == @prompt[:index] then Palette::WHITE
            else Palette::GRAY
            end
          if i == @prompt[:index]
            Px.frame(x - cell / 2 + 3, 100, cell - 6, 34,
                     Palette.alpha(Palette::YELLOW, blinking_alpha(8.0)), 181)
          end
          Px.text_shadow(Assets.large, symbol, x, 104, tone, 182, align: :center)
        end

        bar = width - 12
        Px.rect(left + 6, 138, bar, 4, Palette.rgb(0x3a2244), 182)
        Px.rect(left + 6, 138, (bar * ratio).round, 4,
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
