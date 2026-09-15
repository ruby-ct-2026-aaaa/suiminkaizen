# frozen_string_literal: true

module Suiminkaizen
  module Minigames
    # 筋トレ（バーベルスクワット）。
    #
    # 左右に往復するパワーゲージを、緑のゾーンで止める＝1レップ成立。
    # 中心の黄色ゾーンで止めると PERFECT で3倍近い価値になる。
    # 4レップごとにゲージが速く、ゾーンが狭くなっていくので、
    # 粘るほど1回あたりの睡眠ゲージ削減量が伸びる。
    class Muscle < Base
      KOSUKE_Z = 4.2

      METER_X = 44
      METER_W = 232
      METER_Y = 184
      METER_H = 15

      class << self
        def kind  = :muscle
        def title = "深夜の筋トレ"
        def subtitle = "バーベルスクワット"
        def theme = :gym
        def target_score = 118.0

        def controls
          ["SPACE ... バーベルを上げる"]
        end

        def rules
          [
            "左右に往復するパワーゲージを緑のゾーンで止める。",
            "中央の黄色で止めれば PERFECT ＝ 大幅に効率アップ。",
            "外すとフォームが崩れて、その場で眠気が増える。",
            "4レップごとにゲージが速く、ゾーンは狭くなる。"
          ]
        end
      end

      def setup
        @cursor = 0.0
        @dir    = 1.0
        @reps   = 0
        @squat  = 0.0
        @squat_phase = :idle
        @sweat  = []
        roll_zone
      end

      def step(dt)
        move_cursor(dt)
        animate_squat(dt)
        update_sweat(dt)
      end

      def button_down(id)
        return unless confirm?(id)

        distance = (@cursor - @zone_center).abs
        if distance <= @perfect_half
          @reps += 1
          succeed(3.0, "PERFECT!", Palette::YELLOW, Config::W / 2, 120)
          burst(10)
          @camera.kick(0.28)
          after_rep
        elsif distance <= @zone_half
          @reps += 1
          succeed(1.6, "GOOD", Palette::GREEN, Config::W / 2, 120)
          burst(4)
          after_rep
        else
          blunder(6.0, "フォームが崩れた ＋6", Config::W / 2, 120)
        end
      end

      private

      def move_cursor(dt)
        speed = (0.52 + (@level - 1) * 0.10) * @difficulty
        @cursor += @dir * speed * dt
        if @cursor > 1.0
          @cursor = 1.0
          @dir = -1.0
        elsif @cursor.negative?
          @cursor = 0.0
          @dir = 1.0
        end
      end

      def after_rep
        @squat_phase = :down
        level_up! if (@reps % 4).zero?
        roll_zone
      end

      def roll_zone
        base = [0.16 - (@level - 1) * 0.0115, 0.06].max
        @zone_half    = base / (0.85 + 0.15 * @difficulty)
        @perfect_half = @zone_half * 0.34
        @zone_center  = 0.22 + rand * 0.56
      end

      def animate_squat(dt)
        case @squat_phase
        when :down
          @squat += dt * 5.5
          if @squat >= 1.0
            @squat = 1.0
            @squat_phase = :up
          end
        when :up
          @squat -= dt * 4.0
          if @squat <= 0.0
            @squat = 0.0
            @squat_phase = :idle
          end
        end
      end

      # 汗。成功したときだけ飛ぶ。
      def burst(count)
        sx, sy, = @camera.project(0.0, Stage::FLOOR_Y - 1.35, KOSUKE_Z)
        count.times do
          @sweat << { x: sx, y: sy, vx: (rand - 0.5) * 90.0, vy: -20.0 - rand * 55.0,
                      life: 0.7 }
        end
      end

      def update_sweat(dt)
        @sweat.each do |s|
          s[:x] += s[:vx] * dt
          s[:y] += s[:vy] * dt
          s[:vy] += 170.0 * dt
          s[:life] -= dt
        end
        @sweat.reject! { |s| s[:life] <= 0.0 }
      end

      # --- 描画 -----------------------------------------------------------

      def scene_draw
        draw_shadow(0.0, KOSUKE_Z, 0.5)
        draw_kosuke
        draw_sweat
        draw_meter
      end

      BAR_HALF = 0.82

      def draw_kosuke
        height = 1.55 * (1.0 - 0.22 * @squat)
        Sprites::KOSUKE.draw3d(@camera, 0.0, Stage::FLOOR_Y, KOSUKE_Z, height,
                               fog: Stage.fog(:gym))
        # 肩の高さ ＝ スプライトの上から約4割の位置（あごのすぐ下）。
        draw_barbell(Stage::FLOOR_Y - height * 0.60)
      end

      def draw_barbell(y)
        z     = KOSUKE_Z - 0.4
        scale = @camera.scale_at(z)
        order = Config.depth_z(z) + 1

        left  = @camera.project(-BAR_HALF, y, z)
        right = @camera.project(BAR_HALF, y, z)
        thickness = [(0.05 * scale).round, 2].max

        draw_arms(y, z, scale, order)

        Px.rect(left[0], left[1], right[0] - left[0], thickness, Palette::STEEL, order)
        Px.rect(left[0], left[1], right[0] - left[0], 1,
                Palette.mix(Palette::STEEL, Palette::WHITE, 0.5), order + 1)

        plate_h = [(0.30 * scale).round, 4].max
        plate_w = [(0.15 * scale).round, 3].max
        [left, right].each do |point|
          px = point[0] - plate_w / 2.0
          py = point[1] + thickness / 2.0 - plate_h / 2.0
          Px.rect(px, py, plate_w, plate_h, Palette::INK, order + 2)
          Px.rect(px + 1, py + 1, plate_w - 2, plate_h - 2, Palette::CRIMSON, order + 3)
        end
      end

      # バーを握る腕。肩から斜めにバーへ伸ばす。
      def draw_arms(bar_y, z, scale, order)
        shoulder_y = bar_y + 0.16
        width = [(0.07 * scale).round, 2].max
        [-1, 1].each do |side|
          top = @camera.project(side * 0.42, shoulder_y, z)
          hand = @camera.project(side * BAR_HALF * 0.72, bar_y, z)
          steps = 6
          (0..steps).each do |i|
            t = i / steps.to_f
            Px.rect(top[0] + (hand[0] - top[0]) * t - width / 2.0,
                    top[1] + (hand[1] - top[1]) * t - width / 2.0,
                    width, width, Palette::SKIN, order)
          end
        end
      end

      def draw_sweat
        @sweat.each do |s|
          alpha = (255 * [s[:life] / 0.7, 1.0].min).round
          Px.rect(s[:x], s[:y], 2, 3, Palette.alpha(Palette::AQUA, alpha), 120)
        end
      end

      def draw_meter
        z = 150
        Px.rect(METER_X - 3, METER_Y - 3, METER_W + 6, METER_H + 6, Palette::INK, z)
        Px.rect(METER_X, METER_Y, METER_W, METER_H, Palette.rgb(0x241f42), z + 1)

        # 目盛り
        (1..11).each do |i|
          Px.rect(METER_X + (METER_W * i / 12.0).round, METER_Y + METER_H - 4, 1, 3,
                  Palette.alpha(Palette::WHITE, 45), z + 2)
        end

        zone_x = METER_X + (@zone_center - @zone_half) * METER_W
        zone_w = @zone_half * 2 * METER_W
        Px.rect(zone_x, METER_Y, zone_w, METER_H, Palette.alpha(Palette::GREEN, 190), z + 3)

        perfect_x = METER_X + (@zone_center - @perfect_half) * METER_W
        perfect_w = @perfect_half * 2 * METER_W
        Px.rect(perfect_x, METER_Y, perfect_w, METER_H, Palette::YELLOW, z + 4)

        cursor_x = METER_X + @cursor * METER_W
        Px.rect(cursor_x - 1, METER_Y - 4, 3, METER_H + 8, Palette::WHITE, z + 5)
        Px.rect(cursor_x - 1, METER_Y - 4, 3, 3, Palette::RED, z + 6)

        Px.text_shadow(Assets.tiny, "#{@reps} レップ", METER_X, METER_Y - 15,
                       Palette::BONE, z + 6)
        Px.text_shadow(Assets.tiny, "SPACE で上げる", METER_X + METER_W,
                       METER_Y - 15, Palette.alpha(Palette::WHITE, blinking_alpha(6.0)),
                       z + 6, align: :right)
      end
    end
  end
end
