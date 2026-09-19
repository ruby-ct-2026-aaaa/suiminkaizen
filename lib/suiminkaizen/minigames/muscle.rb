# frozen_string_literal: true

module Suiminkaizen
  module Minigames
    # 筋トレ（バーベルスクワット）。
    #
    # 3つを同時にさばく種目。
    #   1. 左右に往復するパワーゲージを緑のゾーンで止める（SPACE）＝1レップ。
    #   2. バーベルの軸は放っておくと左右にブレる。← → で中央へ戻しつづける。
    #   3. 呼吸は勝手に切れていく。↑（吸う）と ↓（吐く）を交互に押して保つ。
    # 軸がブレたまま、あるいは息が切れたまま上げると事故になる。
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
        def target_score = 61.0

        def controls
          ["SPACE ... バーベルを上げる　　← → ... 軸のブレを戻す",
           "↑ ↓ ... 息を吸う／吐く（交互に押しつづける）"]
        end

        def rules
          [
            "往復するパワーゲージを緑（中央の黄色なら PERFECT）で止める。",
            "同時に ← → でバーベルの軸のブレを中央へ戻しつづける。",
            "↑ と ↓ を交互に押して呼吸を切らさない。同じ側の連打は逆効果。",
            "軸がブレたまま上げる・息が切れる・よろけると、その場で眠気が増える。"
          ]
        end
      end

      # 軸がこれ以上ブレていると、上げた瞬間に事故になる。
      TILT_LIMIT = 0.62

      attr_reader :balance, :breath, :last_breath

      def setup
        @cursor = 0.0
        @dir    = 1.0
        @reps   = 0
        @squat  = 0.0
        @squat_phase = :idle
        @sweat  = []
        @balance     = 0.0
        @balance_vel = 0.0
        @stumble     = 0.0
        @breath      = 1.0
        @last_breath = nil
        roll_zone
      end

      def step(dt)
        move_cursor(dt)
        sway_balance(dt)
        exhale(dt)
        animate_squat(dt)
        update_sweat(dt)
      end

      def button_down(id)
        super
        case id
        when Gosu::KB_LEFT,  Gosu::KB_A then lean(-1.0)
        when Gosu::KB_RIGHT, Gosu::KB_D then lean(1.0)
        when Gosu::KB_UP,    Gosu::KB_W then breathe(:in)
        when Gosu::KB_DOWN,  Gosu::KB_S then breathe(:out)
        else press_up if confirm?(id)
        end
      end

      private

      # --- 軸のブレ -------------------------------------------------------

      # バーベルは放っておけばゆっくり傾いていく。
      def sway_balance(dt)
        push = (0.62 + (@level - 1) * 0.11) * @difficulty
        @balance_vel += (rand - 0.5) * push * dt * 6.0
        @balance_vel *= 0.985
        @balance += @balance_vel * dt
        @stumble -= dt

        return if @balance.abs < 1.0

        @balance     = 0.0
        @balance_vel = 0.0
        return if @stumble.positive?

        @stumble = 1.2
        @camera.kick(0.5)
        blunder(8.0, "よろけた ＋8", Config::W / 2, 120)
      end

      def lean(side)
        @balance += side * 0.26
        @balance_vel *= 0.35
        @balance = -1.0 if @balance < -1.0
        @balance = 1.0 if @balance > 1.0
      end

      # --- 呼吸 -----------------------------------------------------------

      def exhale(dt)
        @breath -= (0.17 + (@level - 1) * 0.024) * @difficulty * dt
        return if @breath.positive?

        @breath = 0.55
        @combo  = 0
        blunder(7.0, "息が上がった ＋7", Config::W / 2, 104)
      end

      # 吸う→吐く→吸う…と交互に押せたときだけ呼吸が戻る。
      def breathe(phase)
        if @last_breath == phase
          @breath -= 0.05
          @breath = 0.0 if @breath.negative?
          popup("呼吸が乱れた", Palette::ORANGE, Config::W / 2, 96)
          return
        end

        @last_breath = phase
        @breath += 0.30
        @breath = 1.0 if @breath > 1.0
      end

      # --- レップ ---------------------------------------------------------

      def press_up
        if @balance.abs > TILT_LIMIT
          @camera.kick(0.4)
          blunder(6.0, "軸がぶれたまま上げた ＋6", Config::W / 2, 120)
          return
        end

        # 軸が安定していて息もあるほど、1レップの価値が上がる。
        quality = (1.0 - @balance.abs * 0.55) * (0.55 + @breath * 0.45)
        distance = (@cursor - @zone_center).abs

        if distance <= @perfect_half
          @reps += 1
          Sound.play(:perfect)
          succeed(3.0 * quality, "PERFECT!", Palette::YELLOW, Config::W / 2, 120)
          burst(10)
          @camera.kick(0.28)
          after_rep
        elsif distance <= @zone_half
          @reps += 1
          Sound.play(:good)
          succeed(1.6 * quality, "GOOD", Palette::GREEN, Config::W / 2, 120)
          burst(4)
          after_rep
        else
          blunder(6.0, "フォームが崩れた ＋6", Config::W / 2, 120)
        end
      end

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
        draw_breath_meter
        draw_balance_meter
        draw_meter
      end

      BREATH_Y  = 140
      BALANCE_Y = 156

      def draw_breath_meter
        z = 150
        Px.text_shadow(Assets.tiny, "呼吸", METER_X - 38, BREATH_Y - 2,
                       Palette::BONE, z + 6)
        # 峰小輔が隠れないよう、2本の補助メーターは半透明にしておく。
        Px.rect(METER_X - 1, BREATH_Y - 1, METER_W + 2, 9, Palette.alpha(Palette::INK, 170), z)
        Px.rect(METER_X, BREATH_Y, METER_W, 7, Palette.alpha(Palette::INK, 120), z + 1)

        tone = @breath < 0.3 ? Palette::RED : Palette::AQUA
        Px.rect(METER_X, BREATH_Y, (METER_W * @breath).round, 7,
                Palette.alpha(tone, 210), z + 2)

        label = @last_breath == :in ? "つぎは ↓ 吐く" : "つぎは ↑ 吸う"
        Px.text_shadow(Assets.tiny, label, METER_X + METER_W, BREATH_Y - 2,
                       Palette.alpha(Palette::WHITE, blinking_alpha(5.0)), z + 6,
                       align: :right)
      end

      # 軸のブレ。中央の白い枠から出そうになったら ← → で戻す。
      def draw_balance_meter
        z = 150
        center = METER_X + METER_W / 2.0
        Px.text_shadow(Assets.tiny, "軸", METER_X - 38, BALANCE_Y - 2,
                       Palette::BONE, z + 6)
        Px.rect(METER_X - 1, BALANCE_Y - 1, METER_W + 2, 9, Palette.alpha(Palette::INK, 170), z)
        Px.rect(METER_X, BALANCE_Y, METER_W, 7, Palette.alpha(Palette::INK, 120), z + 1)

        safe_w = METER_W * TILT_LIMIT
        Px.rect(center - safe_w / 2.0, BALANCE_Y, safe_w, 7,
                Palette.alpha(Palette::GREEN, 120), z + 2)
        Px.rect(center, BALANCE_Y, 1, 7, Palette.alpha(Palette::WHITE, 120), z + 3)

        tone = @balance.abs > TILT_LIMIT ? Palette::RED : Palette::WHITE
        Px.rect(center + @balance * METER_W / 2.0 - 2, BALANCE_Y - 2, 5, 11, tone, z + 4)
      end

      BAR_HALF = 0.82

      # 取り込んだ峰小輔の立ち絵を使う。用意できていなければドット絵で代用する。
      def draw_kosuke
        height = 1.55 * (1.0 - 0.22 * @squat)
        sprite = Assets.portrait(:normal)

        unless sprite
          Sprites::KOSUKE.draw3d(@camera, 0.0, Stage::FLOOR_Y, KOSUKE_Z, height,
                                 fog: Stage.fog(:gym))
          # ドット絵は全身なので、肩は上から約4割の位置（あごのすぐ下）。
          return draw_barbell(Stage::FLOOR_Y - height * 0.60)
        end

        sprite.draw3d(@camera, 0.0, Stage::FLOOR_Y, KOSUKE_Z, height,
                      fog: Stage.fog(:gym))
        # 立ち絵はバストアップで、肩は下から約4割の高さに来る。
        # 腕は絵のほうに描かれているので、こちらでは足さない。
        draw_barbell(Stage::FLOOR_Y - height * 0.40, arms: false)
      end

      def draw_barbell(y, arms: true)
        z     = KOSUKE_Z - 0.4
        scale = @camera.scale_at(z)
        order = Config.depth_z(z) + 1

        left  = @camera.project(-BAR_HALF, y, z)
        right = @camera.project(BAR_HALF, y, z)
        thickness = [(0.05 * scale).round, 2].max

        draw_arms(y, z, scale, order) if arms

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
