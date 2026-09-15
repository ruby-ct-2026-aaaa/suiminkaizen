# frozen_string_literal: true

module Suiminkaizen
  module Minigames
    # サプリメント。
    #
    # 奥からサプリが3レーンに分かれて迫ってくる。
    # 左右キーでコップを構え、手前の判定ゾーンに来た瞬間に SPACE で飲む。
    # 暖色＝目が覚める良いサプリ、寒色＝眠くなる危険物。
    # 危険物は飲まずに見送るのが正解で、見送るだけでも少し加点される。
    class Supplement < Base
      LANES   = [-1.45, 0.0, 1.45].freeze
      PILL_Y  = 1.15
      SPAWN_Z = Stage::FAR_Z
      CATCH_NEAR = 1.45
      CATCH_FAR  = 2.85
      CATCH_BEST = 2.05
      GONE_Z  = 1.1

      TYPES = [
        { name: "カフェイン",   good: true,  shape: :tablet,
          a: Palette::ORANGE, b: Palette.shade(Palette::ORANGE, 0.6) },
        { name: "ビタミンB",    good: true,  shape: :capsule,
          a: Palette::YELLOW, b: Palette::GOLD },
        { name: "タウリン",     good: true,  shape: :capsule,
          a: Palette::RED,    b: Palette::CRIMSON },
        { name: "マカ",         good: true,  shape: :tablet,
          a: Palette::GREEN,  b: Palette::MOSS },
        { name: "睡眠薬",       good: false, shape: :capsule,
          a: Palette::BLUE,   b: Palette::DEEP_BLUE },
        { name: "メラトニン",   good: false, shape: :tablet,
          a: Palette::LILAC,  b: Palette::VIOLET },
        { name: "ホットミルク", good: false, shape: :tablet,
          a: Palette::WHITE,  b: Palette::BONE }
      ].freeze

      GOOD = TYPES.select { |t| t[:good] }.freeze
      BAD  = TYPES.reject { |t| t[:good] }.freeze

      class << self
        def kind  = :supplement
        def title = "サプリメント"
        def subtitle = "効くやつだけ飲み込め"
        def theme = :kitchen
        def target_score = 130.0

        def controls
          ["← → ... コップを動かす", "SPACE ... 飲む"]
        end

        def rules
          [
            "奥から迫るサプリを、手前の判定ゾーンで SPACE。",
            "暖色（カフェイン・ビタミン・タウリン・マカ）は飲む。",
            "寒色（睡眠薬・メラトニン・ホットミルク）は見送る。",
            "危険物を飲むと大ダメージ。見送れば少し加点。"
          ]
        end
      end

      def setup
        @lane   = 1
        @pills  = []
        @spawn  = 0.7
        @caught = 0
        @sparks = []
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
            succeed(1.0, "見送った", Palette::GREEN, lane_screen_x(p[:lane]), 150)
          end
        end
        @pills.reject! { |p| p[:done] }

        update_sparks(dt)
      end

      def button_down(id)
        case id
        when Gosu::KB_LEFT,  Gosu::KB_A then @lane = [@lane - 1, 0].max
        when Gosu::KB_RIGHT, Gosu::KB_D then @lane = [@lane + 1, LANES.size - 1].min
        else
          drink if confirm?(id)
        end
      end

      private

      def spawn_pill
        bad_ratio = [0.30 + (@level - 1) * 0.035, 0.52].min
        type = rand < bad_ratio ? BAD.sample : GOOD.sample
        @pills << { type: type, lane: rand(LANES.size), z: SPAWN_Z,
                    spin: rand * 6.28, done: false }

        interval = [1.30 - (@level - 1) * 0.075, 0.55].max / @difficulty
        @spawn = interval * (0.85 + rand * 0.3)
      end

      def drink
        target = @pills.select do |p|
          p[:lane] == @lane && p[:z] >= CATCH_NEAR && p[:z] <= CATCH_FAR
        end.min_by { |p| (p[:z] - CATCH_BEST).abs }

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
          precise = (target[:z] - CATCH_BEST).abs < 0.3
          if precise
            succeed(3.2, "#{target[:type][:name]} JUST!", Palette::YELLOW, x, 150)
          else
            succeed(2.1, target[:type][:name], Palette::GREEN, x, 150)
          end
          spark(x, target[:type][:a])
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
        draw_legend
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
        Px.text_shadow(Assets.tiny, "暖色＝飲む　寒色＝見送る", Config::W / 2, 44,
                       Palette::BONE, 150, align: :center)
      end
    end
  end
end
