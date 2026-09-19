# frozen_string_literal: true

module Suiminkaizen
  module Minigames
    # サプリメント。
    #
    # 奥からサプリが3レーンに分かれて迫ってくる。
    # 左右キーでコップを構え、手前の判定ゾーンで、
    #   寒色（ひんやり目が覚める）＝ SPACE で飲む
    #   暖色（身体が温まって眠くなる）＝ ↓ で払いのける
    # と使い分ける。さらに飲んだ直後はのどに残るので、
    # 短いあいだに ↑ で水を流し込まないとむせて眠気が増える。
    # 飲む・払う・流し込むの3手を、レーン移動と並行してさばく種目。
    class Supplement < Base
      LANES   = [-1.45, 0.0, 1.45].freeze
      PILL_Y  = 1.15
      SPAWN_Z = Stage::FAR_Z
      CATCH_NEAR = 1.45
      CATCH_FAR  = 2.85
      CATCH_BEST = 2.05
      GONE_Z  = 1.1

      # 見分けかたは色温度ひとつ。
      #   寒色＝ひんやり目が覚めるもの → 飲む（睡眠ゲージが減る）
      #   暖色＝身体が温まって眠くなるもの → 見送る（飲むとゲージが増える）
      TYPES = [
        { name: "カフェイン",   good: true,  shape: :tablet,
          a: Palette::BLUE,   b: Palette::DEEP_BLUE },
        { name: "ミント",       good: true,  shape: :tablet,
          a: Palette::CYAN,   b: Palette.shade(Palette::CYAN, 0.6) },
        { name: "タウリン",     good: true,  shape: :capsule,
          a: Palette::AQUA,   b: Palette::CYAN },
        { name: "エナジー",     good: true,  shape: :capsule,
          a: Palette::LILAC,  b: Palette::VIOLET },
        { name: "ホットミルク", good: false, shape: :tablet,
          a: Palette::ORANGE, b: Palette::BROWN },
        { name: "カモミール",   good: false, shape: :tablet,
          a: Palette::YELLOW, b: Palette::GOLD },
        { name: "甘酒",         good: false, shape: :capsule,
          a: Palette::RED,    b: Palette::CRIMSON }
      ].freeze

      GOOD = TYPES.select { |t| t[:good] }.freeze
      BAD  = TYPES.reject { |t| t[:good] }.freeze

      class << self
        def kind  = :supplement
        def title = "サプリメント"
        def subtitle = "冷たいものだけ飲み込め"
        def theme = :kitchen
        def target_score = 66.0

        def controls
          ["← → ... コップを動かす　　SPACE ... 飲む（寒色）",
           "↓ ... 払いのける（暖色）　　↑ ... 飲んだ直後に水で流し込む"]
        end

        def rules
          [
            "寒色（カフェイン・ミント・タウリン・エナジー）は SPACE で飲む。",
            "暖色（ホットミルク・カモミール・甘酒）は ↓ で払いのける。",
            "飲んだら「水！」の合図のうちに ↑。遅れるとむせて眠気が増える。",
            "暖色を飲む・寒色を払う・飲み逃す、どれも大ダメージ。"
          ]
        end
      end

      # 飲んでから水で流し込むまでの猶予。
      CHASE_SPAN = 0.85

      attr_reader :chase

      def setup
        @lane   = 1
        @pills  = []
        @spawn  = 0.7
        @caught = 0
        @sparks = []
        @chase  = nil
      end

      def step(dt)
        @spawn -= dt
        spawn_pill if @spawn <= 0.0

        speed = (2.1 + (@level - 1) * 0.26) * @difficulty
        @pills.each { |p| p[:z] -= speed * dt }

        @pills.each do |p|
          next if p[:z] > GONE_Z

          p[:done] = true
          if p[:type][:good]
            blunder(3.0, "飲み逃した ＋3", lane_screen_x(p[:lane]), 150)
          else
            # 見送るだけでも事故にはならないが、払いのけたほうがずっと得。
            succeed(0.4, "見送った", Palette::GREEN, lane_screen_x(p[:lane]), 150)
          end
        end
        @pills.reject! { |p| p[:done] }

        update_chase(dt)
        update_sparks(dt)
      end

      def button_down(id)
        super
        case id
        when Gosu::KB_LEFT,  Gosu::KB_A then @lane = [@lane - 1, 0].max
        when Gosu::KB_RIGHT, Gosu::KB_D then @lane = [@lane + 1, LANES.size - 1].min
        when Gosu::KB_UP,    Gosu::KB_W then chase_with_water
        when Gosu::KB_DOWN,  Gosu::KB_S then flick
        else
          drink if confirm?(id)
        end
      end

      private

      # --- 水で流し込む ---------------------------------------------------

      def update_chase(dt)
        return unless @chase

        @chase[:left] -= dt
        return if @chase[:left].positive?

        @chase = nil
        @combo = 0
        blunder(5.0, "むせた ＋5", Config::W / 2, 124)
      end

      def chase_with_water
        unless @chase
          popup("水だけ飲んだ", Palette::GRAY, Config::W / 2, 124)
          return
        end

        # 早いほど気持ちよく流し込める。
        speed = @chase[:left] / CHASE_SPAN
        succeed(1.2 + speed * 1.2, "水で流し込んだ！", Palette::AQUA,
                Config::W / 2, 124)
        @chase = nil
      end

      # --- 払いのける -----------------------------------------------------

      def flick
        target = pill_in_zone
        unless target
          @combo = 0
          popup("空振り", Palette::GRAY, lane_screen_x(@lane), 150)
          return
        end

        target[:done] = true
        @pills.delete(target)
        x = lane_screen_x(target[:lane])
        Sound.play(:flick) # 振り払った

        if target[:type][:good]
          blunder(6.0, "#{target[:type][:name]}を払ってしまった ＋6", x, 150)
        else
          succeed(2.4, "#{target[:type][:name]}を払った！", Palette::GREEN, x, 150)
          spark(x, Palette::GREEN)
        end
      end

      def pill_in_zone
        @pills.select do |p|
          p[:lane] == @lane && p[:z] >= CATCH_NEAR && p[:z] <= CATCH_FAR
        end.min_by { |p| (p[:z] - CATCH_BEST).abs }
      end

      def spawn_pill
        bad_ratio = [0.30 + (@level - 1) * 0.035, 0.52].min
        type = rand < bad_ratio ? BAD.sample : GOOD.sample
        @pills << { type: type, lane: rand(LANES.size), z: SPAWN_Z,
                    spin: rand * 6.28, done: false }

        interval = [1.30 - (@level - 1) * 0.075, 0.55].max / @difficulty
        @spawn = interval * (0.85 + rand * 0.3)
      end

      def drink
        target = pill_in_zone

        unless target
          @combo = 0
          popup("空振り", Palette::GRAY, lane_screen_x(@lane), 150)
          return
        end

        target[:done] = true
        @pills.delete(target)
        x = lane_screen_x(target[:lane])

        if target[:type][:good]
          @caught += 1
          Sound.play(:supplement)
          precise = (target[:z] - CATCH_BEST).abs < 0.3
          if precise
            succeed(3.2, "#{target[:type][:name]} JUST!", Palette::YELLOW, x, 150)
          else
            succeed(2.1, target[:type][:name], Palette::GREEN, x, 150)
          end
          spark(x, target[:type][:a])
          @chase = { left: CHASE_SPAN }
          level_up! if (@caught % 6).zero?
        else
          blunder(10.0, "#{target[:type][:name]}を飲んだ ＋10", x, 150)
        end
      end

      def lane_screen_x(lane)
        @camera.project(LANES[lane], PILL_Y, CATCH_BEST)[0]
      end

      def spark(x, color)
        8.times do
          @sparks << { x: x, y: 180, vx: (rand - 0.5) * 110, vy: -40 - rand * 70,
                       life: 0.5, color: color }
        end
      end

      def update_sparks(dt)
        @sparks.each do |s|
          s[:x] += s[:vx] * dt
          s[:y] += s[:vy] * dt
          s[:vy] += 190 * dt
          s[:life] -= dt
        end
        @sparks.reject! { |s| s[:life] <= 0.0 }
      end

      # --- 描画 -----------------------------------------------------------

      def scene_draw
        draw_lanes
        draw_catch_zone
        draw_pills
        draw_cup
        draw_sparks
        draw_chase if @chase
        draw_legend
      end

      # 飲んだ直後に出る「水！」の合図。
      def draw_chase
        ratio = @chase[:left] / CHASE_SPAN
        Px.rect(Config::W / 2 - 62, 108, 124, 26, Palette.alpha(Palette::INK, 200), 180)
        Px.text_shadow(Assets.small, "↑ 水！", Config::W / 2, 110,
                       Palette::AQUA, 181, align: :center)
        Px.rect(Config::W / 2 - 56, 128, 112, 3, Palette.rgb(0x3a2244), 181)
        Px.rect(Config::W / 2 - 56, 128, (112 * ratio).round, 3, Palette::YELLOW, 182)
      end

      RAIL_Y     = PILL_Y + 0.24 # サプリが滑ってくるレールの高さ
      GUIDE_NEAR = 2.0
      GUIDE_FAR  = 9.5

      # 3本のレール。消失点へ収束する線が、そのまま奥行きの手がかりになる。
      def draw_lanes
        LANES.each_with_index do |x, i|
          current = i == @lane
          color = current ? Palette::YELLOW : Palette::AQUA
          Stage.stripe(@camera, RAIL_Y, x - 0.04, x + 0.04,
                       Palette.alpha(color, current ? 150 : 45),
                       Palette.alpha(color, 0), 6, GUIDE_NEAR, GUIDE_FAR)
        end
      end

      # 飲める奥行きの範囲。いま構えているレーンだけを光らせる。
      def draw_catch_zone
        order = Config.depth_z(CATCH_NEAR) - 1
        pulse = (Math.sin(elapsed * 6.0) + 1.0) * 0.5
        x = LANES[@lane]

        near = Palette.alpha(Palette::CYAN, (55 + pulse * 45).round)
        far  = Palette.alpha(Palette::CYAN, 18)
        Stage.patch(@camera, x - 0.34, x + 0.34, CATCH_NEAR, CATCH_FAR,
                    RAIL_Y, near, far, order)

        a = @camera.project(x - 0.38, RAIL_Y, CATCH_BEST)
        b = @camera.project(x + 0.38, RAIL_Y, CATCH_BEST)
        Px.rect(a[0], a[1], b[0] - a[0], 2,
                Palette.alpha(Palette::WHITE, (120 + pulse * 90).round), order + 1)
      end

      def draw_pills
        @pills.sort_by { |p| -p[:z] }.each do |p|
          sprite = p[:type][:shape] == :capsule ? Sprites::CAPSULE : Sprites::TABLET
          palette = { "A" => p[:type][:a], "B" => p[:type][:b] }
          bob = Math.sin(elapsed * 3.0 + p[:spin]) * 0.04

          sprite.draw3d(@camera, LANES[p[:lane]], PILL_Y + bob, p[:z], 0.38,
                        palette: palette, fog: Stage.fog(:kitchen))

          next if p[:z] > 5.0

          sx, sy, scale = @camera.project(LANES[p[:lane]], PILL_Y + bob, p[:z])
          alpha = [(5.0 - p[:z]) / 1.5, 1.0].min
          Px.text_shadow(Assets.tiny, p[:type][:name], sx, sy - 0.42 * scale - 10,
                         Palette.alpha(p[:type][:good] ? Palette::WHITE : Palette::RED,
                                       (alpha * 220).round),
                         Config.depth_z(p[:z]) + 1, align: :center)
        end
      end

      def draw_cup
        x = LANES[@lane]
        Sprites::GLASS.draw3d(@camera, x, 1.40, CATCH_BEST, 0.46)

        sx, sy, scale = @camera.project(x, 1.40, CATCH_BEST)
        width = 0.40 * scale
        Px.rect(sx - width / 2, sy + 2, width, 2,
                Palette.alpha(Palette::YELLOW, blinking_alpha(7.0, 90)), 140)
      end

      def draw_sparks
        @sparks.each do |s|
          alpha = (255 * [s[:life] / 0.5, 1.0].min).round
          Px.rect(s[:x], s[:y], 2, 2, Palette.alpha(s[:color], alpha), 145)
        end
      end

      def draw_legend
        Px.text_shadow(Assets.tiny, "寒色＝SPACEで飲む　暖色＝↓で払う　飲んだら↑で水", Config::W / 2, 44,
                       Palette::BONE, 150, align: :center)
      end
    end
  end
end
