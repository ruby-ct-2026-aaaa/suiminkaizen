# frozen_string_literal: true

module Suiminkaizen
  module Minigames
    ALL_KINDS = %i[muscle bath supplement].freeze

    module_function

    def registry
      { muscle: Muscle, bath: Bath, supplement: Supplement }
    end

    def klass(kind)
      registry.fetch(kind)
    end

    def build(kind, window, state)
      klass(kind).new(window, state)
    end

    # ミニゲーム共通の土台。
    #
    # 各ミニゲームは「制限時間のあいだスコアを稼ぐ」という形に統一してあり、
    #   達成率 = スコア / 目標スコア
    #   削減量 = その日の上限 x 達成率
    # で睡眠ゲージの削減量が決まる。スコアはレベル（種目内の難易度）と
    # コンボで増えるので、"成功難易度に応じて削減量が可変" になる。
    class Base < Scene
      RANKS = [[1.10, "S"], [0.92, "A"], [0.75, "B"], [0.50, "C"]].freeze
      MAX_LEVEL = 8

      attr_reader :level, :combo, :score, :target_score, :time_left, :camera

      class << self
        def kind        = raise(NotImplementedError)
        def title       = raise(NotImplementedError)
        def subtitle    = ""
        def theme       = :gym
        def target_score = 80.0
        def controls    = []
        def rules       = []
      end

      def initialize(window, state)
        super
        @camera        = Camera.new
        @time_left     = Config::MINIGAME_SECONDS
        @score         = 0.0
        @target_score  = self.class.target_score
        @level         = 1
        @combo         = 0
        @max_combo     = 0
        @penalty_total = 0.0
        @popups        = []
        @flash         = 0.0
        @finished      = false
        @difficulty    = Config.difficulty(state.day)
        setup
      end

      # --- サブクラスが実装する ------------------------------------------
      def setup; end
      def step(_dt); end
      def scene_draw; end

      # --- 進行 -----------------------------------------------------------

      def update(dt)
        super
        return if @finished

        @camera.update(dt)
        @flash -= dt * 3.0
        @flash = 0.0 if @flash.negative?

        @time_left -= dt
        state.gauge.add(Config.drowsiness_rate(state.day) * dt)

        step(dt)
        update_popups(dt)

        if state.gauge.fainted?
          @finished = true
          goto(Scenes::GameOver.new(window, state))
        elsif @time_left <= 0.0
          @time_left = 0.0
          @finished  = true
          finish!
        end
      end

      def finish!
        performance = @target_score.positive? ? @score / @target_score : 0.0
        performance = Config::MAX_PERFORMANCE if performance > Config::MAX_PERFORMANCE
        performance = 0.0 if performance.negative?

        reward = Config.max_reward(state.day) * performance
        state.gauge.reduce(reward)

        result = Result.new(kind: self.class.kind, title: self.class.title,
                            score: @score, target: @target_score,
                            performance: performance, reward: reward,
                            rank: rank_for(performance), max_combo: @max_combo,
                            level: @level, penalty: @penalty_total)
        state.record(result)
        goto(Scenes::MinigameResult.new(window, state, result))
      end

      def rank_for(performance)
        RANKS.each { |threshold, rank| return rank if performance >= threshold }
        "D"
      end

      # --- スコア操作 -----------------------------------------------------

      # 成功。レベル（難易度）とコンボが高いほど1回の価値が上がる。
      def succeed(points, text = nil, color = Palette::YELLOW, x = Config::W / 2, y = 132)
        @combo += 1
        @max_combo = @combo if @combo > @max_combo
        @score += points * level_bonus * combo_bonus
        popup(text, color, x, y) if text
      end

      # 失敗。スコアが伸びないだけでなく、その場で眠気が増える。
      def blunder(gauge_penalty, text, x = Config::W / 2, y = 132)
        state.gauge.add(gauge_penalty)
        @penalty_total += gauge_penalty
        @combo = 0
        @flash = 1.0
        @camera.kick(0.55)
        popup(text, Palette::RED, x, y)
      end

      # 時間で伸びるタイプの加点（お風呂用）。コンボは動かさない。
      def gain(points)
        @score += points * level_bonus
      end

      # じわじわ増える眠気（湯冷め・のぼせなど）。演出を伴わない失点。
      def drip(amount)
        state.gauge.add(amount)
        @penalty_total += amount
      end

      def level_bonus
        1.0 + (@level - 1) * 0.08
      end

      def combo_bonus
        1.0 + [@combo, 12].min * 0.012
      end

      def level_up!
        return if @level >= MAX_LEVEL

        @level += 1
        popup("Lv.#{@level} 難易度アップ！", Palette::CYAN, Config::W / 2, 104)
      end

      def performance
        return 0.0 unless @target_score.positive?

        [@score / @target_score, Config::MAX_PERFORMANCE].min
      end

      def reward_preview
        Config.max_reward(state.day) * performance
      end

      # --- 演出 -----------------------------------------------------------

      def popup(text, color, x, y)
        @popups << { text: text, color: color, x: x, y: y, life: 0.9, max: 0.9 }
        @popups.shift while @popups.size > 8
      end

      def update_popups(dt)
        @popups.each { |p| p[:life] -= dt }
        @popups.reject! { |p| p[:life] <= 0.0 }
      end

      def draw_popups
        @popups.each do |p|
          t = 1.0 - p[:life] / p[:max]
          alpha = (255 * (1.0 - t * t)).round
          Px.text_shadow(Assets.small, p[:text], p[:x], p[:y] - t * 16,
                         Palette.alpha(p[:color], alpha), 190, align: :center)
        end
      end

      def draw
        Stage.draw(@camera, self.class.theme, elapsed)
        scene_draw
        draw_popups
        draw_game_hud
        Hud.draw(state, elapsed)
        Hud.draw_drowsiness(state)
        draw_flash
      end

      def draw_flash
        return if @flash <= 0.0

        Px.rect(0, 0, Config::W, Config::H,
                Palette.alpha(Palette::RED, (@flash * 70).round), 260)
      end

      def draw_game_hud
        draw_time_bar
        draw_bottom_panel
      end

      def draw_time_bar
        frac = @time_left / Config::MINIGAME_SECONDS
        Px.rect(0, 26, Config::W, 3, Palette.alpha(Palette::INK, 160), Hud::Z_HUD)
        tone = frac < 0.2 ? Palette::RED : Palette::AQUA
        Px.rect(0, 26, (Config::W * frac).round, 3, tone, Hud::Z_HUD + 1)
      end

      def draw_bottom_panel
        Px.rect(0, 212, Config::W, 28, Palette.alpha(Palette::INK, 175), Hud::Z_HUD)

        Px.text_shadow(Assets.tiny, "Lv.#{@level}", 6, 216, Palette::CYAN, Hud::Z_HUD + 2)
        if @combo >= 2
          Px.text_shadow(Assets.tiny, "#{@combo} COMBO", 6, 228, Palette::YELLOW,
                         Hud::Z_HUD + 2)
        end

        Px.text_shadow(Assets.tiny, "のこり #{format('%4.1f', @time_left)}秒",
                       Config::W - 6, 216, Palette::BONE, Hud::Z_HUD + 2, align: :right)

        # このミニゲームで削れる見込みの睡眠ゲージ
        bar_x = 96
        bar_w = 128
        ratio = [performance / Config::MAX_PERFORMANCE, 1.0].min
        Px.rect(bar_x, 230, bar_w, 5, Palette.rgb(0x241f42), Hud::Z_HUD + 1)
        Px.rect(bar_x, 230, (bar_w * ratio).round, 5, Palette::GREEN, Hud::Z_HUD + 2)
        goal = (bar_w / Config::MAX_PERFORMANCE).round
        Px.rect(bar_x + goal, 229, 1, 7, Palette::WHITE, Hud::Z_HUD + 3)
        Px.text_shadow(Assets.tiny, "削減 #{reward_preview.round}", Config::W / 2, 217,
                       Palette::GREEN, Hud::Z_HUD + 2, align: :center)
      end

      # 疑似3Dの空間へ「地面に落ちる影」を描く小道具。
      def draw_shadow(wx, wz, radius)
        sx, sy, scale = @camera.project(wx, Stage::FLOOR_Y, wz)
        w = radius * scale
        Px.rect(sx - w, sy - w * 0.22, w * 2, w * 0.44,
                Palette.alpha(Palette::INK, 110), Config.depth_z(wz) - 0.5)
      end
    end
  end
end
