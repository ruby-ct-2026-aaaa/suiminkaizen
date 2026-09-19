# frozen_string_literal: true

module Suiminkaizen
  # 乱入してくる動物「クイヤ」。
  #
  # 睡眠ゲージが 600 を超えると、普通以上の難易度でどこからか湧いてくる。
  # 居座っているあいだ、眠気の進みが 1匹につき 5% 速くなる。
  # クイヤは「9」が大の苦手なので、9キーを連打すれば追い払える。
  module Kuiya
    # 1匹を追い払うのに必要な「9」の回数。
    HITS_TO_DEFEAT = 9

    # 9 として受け付けるキー（テンキーも可）。
    KEYS = [Gosu::KB_9, Gosu::KB_NUMPAD_9].freeze

    # 世界座標での歩きまわる範囲と背丈。
    LEFT_X   = -2.2
    RIGHT_X  =  2.2
    NEAR_Z   =  2.6
    FAR_Z    =  5.2
    HEIGHT   =  0.62

    WALK_SPEED = 0.55
    RUN_SPEED  = 1.9

    WALK_FPS      = 9.0
    RUN_FPS       = 14.0
    SURPRISE_TIME = 0.45 # 9 を食らってのけぞっている時間
    FLEE_TIME     = 1.2  # ゲージが下がって帰っていくときの時間
    DEFEAT_TIME   = 0.5  # 9発目を食らってから消えるまで
    DEFEAT_JUMP   = 0.85 # 跳ね上がる高さ（世界座標）

    # 鳴き声の間隔。その場にいるあいだ、きっちりこの秒数ごとに鳴く。
    CRY_INTERVAL = 4.0

    # 1匹ぶん。
    class Beast
      attr_reader :hits, :state

      def initialize(from_left)
        @dir   = from_left ? 1.0 : -1.0
        @x     = from_left ? LEFT_X - 0.5 : RIGHT_X + 0.5
        @z     = NEAR_Z + rand * (FAR_Z - NEAR_Z)
        @phase = rand * 6.28
        @state = :walk
        @timer = 0.0
        @hits  = 0
        @cry   = CRY_INTERVAL
        @flee  = 0.0
        @fade  = 0.0
      end

      def x = @x
      def z = @z
      def facing_right? = @dir.positive?

      # 追い払われて画面外へ走り去る途中か。
      def fleeing? = @state == :flee

      # 9発目を食らって、跳ねながら消えていく途中か。
      def defeated? = @state == :defeated

      # 数え上げの対象。退治したぶん・帰ったぶんはもう眠気を増やさない。
      def counted? = !fleeing? && !defeated?

      # 消えかけの濃さ（1.0 = はっきり / 0.0 = 透明）。
      def opacity
        return 1.0 unless defeated?

        [@fade / DEFEAT_TIME, 0.0].max
      end

      def gone?
        return @fade <= 0.0 if defeated?
        return false unless fleeing?

        @flee <= 0.0 || @x < LEFT_X - 1.6 || @x > RIGHT_X + 1.6
      end

      def update(dt)
        @timer += dt
        @phase += dt

        case @state
        when :surprised
          @timer >= SURPRISE_TIME ? calm_down : nil
        when :defeated
          @fade -= dt # その場から動かず、薄くなって消える
        when :flee
          @flee -= dt
          @x += @dir * RUN_SPEED * dt
        else
          wander(dt)
        end
      end

      def wander(dt)
        speed = @state == :run ? RUN_SPEED : WALK_SPEED
        @x += @dir * speed * dt

        # 端まで来たら向きを変える。
        if @x < LEFT_X
          @x = LEFT_X
          @dir = 1.0
        elsif @x > RIGHT_X
          @x = RIGHT_X
          @dir = -1.0
        end

        # ときどき走ったり、立ち止まったりする。
        return if @timer < 1.4

        @timer = 0.0
        @state = %i[walk walk run idle].sample
      end

      def calm_down
        @timer = 0.0
        @state = :walk
      end

      # 9 を1回浴びた。
      def strike!
        @hits += 1
        @state = :surprised
        @timer = 0.0
        @hits >= HITS_TO_DEFEAT
      end

      def flee!
        @state = :flee
        @flee  = FLEE_TIME
        @timer = 0.0
      end

      # 9発目。その場で飛び跳ねながら、0.5秒かけて消える。
      def defeat!
        @state = :defeated
        @fade  = DEFEAT_TIME
        @timer = 0.0
      end

      # 鳴き声のタイミングになったか。4秒おきにひと声。
      def cry?(dt)
        @cry -= dt
        return false if @cry.positive?

        @cry = CRY_INTERVAL
        true
      end

      # いま表示するコマ。
      def frame
        case @state
        when :surprised then :surprised
        when :defeated  then :surprised # 跳ねているあいだも驚いた顔のまま
        when :idle      then :idle
        when :flee      then run_frame
        when :run       then run_frame
        else                 walk_frame
        end
      end

      def walk_frame
        :"walk#{(@phase * WALK_FPS).to_i % 6 + 1}"
      end

      def run_frame
        :"run#{(@phase * RUN_FPS).to_i % 4 + 1}"
      end

      # のけぞっているあいだは少し跳ねる。
      # 退治されたときは、消えるまで大きく跳ね上がる。
      def hop
        case @state
        when :surprised
          Math.sin(@timer / SURPRISE_TIME * Math::PI) * 0.22
        when :defeated
          Math.sin([@timer / DEFEAT_TIME, 1.0].min * Math::PI) * DEFEAT_JUMP
        else
          0.0
        end
      end
    end

    # 群れ全体のとりまとめ。GameState が1つ持つ。
    class Swarm
      SPAWN_INTERVAL = 2.2

      attr_reader :beasts

      def initialize
        @beasts = []
        @spawn  = 0.8
        @active = false
      end

      # 眠気を増やしている匹数。
      def count
        @beasts.count(&:counted?)
      end

      def any? = count.positive?

      # 眠気の倍率。1匹につき 5% 増し。
      def drowsiness_multiplier
        1.0 + Config::KUIYA_RATE_BONUS * count
      end

      # ミニゲーム中だけ動かす。state から上限とゲージを見る。
      def update(dt, state)
        @active = true
        limit = state.kuiya_limit

        @beasts.each { |b| b.update(dt) }
        # その場にいるあいだは 4秒おきにひと声。
        @beasts.each { |b| Sound.play(:kuiya_cry) if b.counted? && b.cry?(dt) }
        @beasts.reject!(&:gone?)

        if unwelcome?(state, limit)
          # ゲージが下がれば、居座る理由もなくなる。
          @beasts.each { |b| b.flee! unless b.fleeing? }
        elsif count < limit
          # まだ枠が空いていれば、そのうち次が湧いてくる。
          @spawn -= dt
          spawn! if @spawn <= 0.0
        end
      end

      # 「もう居られない」条件。上限に達しただけなら、いま居る個体は居座る。
      def unwelcome?(state, limit)
        limit.zero? || state.gauge.value <= Config::KUIYA_THRESHOLD
      end

      def spawn!
        @spawn = SPAWN_INTERVAL
        @beasts << Beast.new(rand < 0.5)
        Sound.play(:kuiya_appear) # 1匹につき1回だけ
      end

      # 「9」が押された。手前にいる1匹から追い払う。
      def strike!(id)
        return false unless KEYS.include?(id)

        target = @beasts.select(&:counted?).max_by(&:z)
        return false unless target

        if target.strike!
          target.defeat! # その場で跳ねて、0.5秒で消える
          Sound.play(:kuiya_defeat)
          return true
        end
        false
      end

      # 1日が終わったら、いったん解散する。
      def clear!
        @beasts.clear
        @spawn = 0.8
      end

      # 乱入してくる側なので、ミニゲームのメーターより手前に描く。
      # 画面いちばん上の時計とゲージ（Z_HUD）には被せない。
      Z_BASE = 160

      def draw(camera)
        # 奥にいるものから描いて、手前のものが上に重なるようにする。
        @beasts.sort_by { |b| -b.z }.each { |b| draw_beast(camera, b) }
        draw_banner if any?
      end

      def draw_beast(camera, beast)
        sprite = Assets.kuiya(beast.frame)
        return unless sprite

        y = Stage::FLOOR_Y - beast.hop
        sprite.draw3d(camera, beast.x, y, beast.z, HEIGHT,
                      z: Z_BASE + (FAR_Z - beast.z),
                      flip: !beast.facing_right?, opacity: beast.opacity)
        draw_damage(camera, beast)
      end

      # 「9を連打」と気づいてもらうための帯。
      def draw_banner
        pulse = (Math.sin(Gosu.milliseconds / 110.0) + 1.0) * 0.5
        text  = "クイヤ #{count} 匹 乱入！　9 を連打！"
        Px.rect(0, 40, Config::W, 13, Palette.alpha(Palette::INK, 185), Z_BASE + 20)
        Px.text_shadow(Assets.tiny, text, Config::W / 2, 42,
                       Palette.mix(Palette::RED, Palette::YELLOW, pulse),
                       Z_BASE + 21, align: :center)
      end

      # 何回 9 を当てたかを、頭の上に点で出す。
      def draw_damage(camera, beast)
        return if beast.hits.zero? || !beast.counted?

        sx, sy, = camera.project(beast.x, Stage::FLOOR_Y - HEIGHT - 0.14, beast.z)
        z = Z_BASE + (FAR_Z - beast.z) + 0.5
        width = HITS_TO_DEFEAT * 3
        left  = sx - width / 2.0

        Px.rect(left - 1, sy - 1, width + 1, 5, Palette.alpha(Palette::INK, 170), z)
        HITS_TO_DEFEAT.times do |i|
          color = i < beast.hits ? Palette::YELLOW : Palette.alpha(Palette::SLATE, 150)
          Px.rect(left + i * 3, sy, 2, 3, color, z + 0.1)
        end
        return unless beast.state == :surprised

        Px.text_shadow(Assets.tiny, "9！", sx, sy - 13, Palette::RED, z + 0.2,
                       align: :center)
      end
    end
  end
end
