# frozen_string_literal: true

module Suiminkaizen
  module Scenes
    # 1枠ぶんの結果。削れた睡眠ゲージと、峰小輔の表情を見せる。
    #
    # A 以上なら得意げな立ち絵、C 以下ならへたりこんだ立ち絵になる。
    class MinigameResult < Scene
      # リザルトを見ているあいだは眠気もゲーム内の時計も止まる。
      # 急がなくていいぶん、最大10秒でひとりでに次へ進む。
      AUTO_NEXT = 10.0
      MIN_SHOW  = 0.0

      RANK_COLORS = {
        "S" => Palette::YELLOW, "A" => Palette::CYAN, "B" => Palette::GREEN,
        "C" => Palette::ORANGE, "D" => Palette::RED, "-" => Palette::SLATE
      }.freeze

      RANK_WORDS = {
        "S" => "完璧だ。眠気が吹き飛んだ。",
        "A" => "いい動きだった。",
        "B" => "まずまず。だが物足りない。",
        "C" => "身が入っていない。",
        "D" => "これでは眠気に勝てない。",
        "-" => "何もしなかった。時間だけが過ぎた。"
      }.freeze

      def initialize(window, state, result)
        super(window, state)
        @result = result
        @camera = Camera.new
      end

      def enter
        state.slot_fraction = 1.0
        state.advance_slot!
      end

      # accumulate_idle を呼ばない ＝ この画面では睡眠ゲージが増えない。
      # 時計も advance_slot! 済みの位置で止まったままになる。
      def update(dt)
        super
        @camera.update(dt)
        continue! if elapsed >= AUTO_NEXT
      end

      def button_down(id)
        continue! if confirm?(id)
      end

      def draw
        Stage.draw(@camera, Minigames.klass(@result.kind).theme, elapsed)
        Px.rect(0, 0, Config::W, Config::H, Palette.alpha(Palette::INK, 190), 100)

        draw_portrait
        Px.rect(14, 38, 196, 164, Palette.alpha(Palette::DUSK, 228), 101)
        Px.frame(14, 38, 196, 164, Palette::VIOLET, 102)
        Px.text_shadow(Assets.small, @result.title, 22, 44, Palette::BONE, 103)

        rank_color = RANK_COLORS.fetch(@result.rank, Palette::WHITE)
        pop = [1.0 + (0.4 - elapsed) * 1.6, 1.0].max
        Px.text_shadow(Assets.title, @result.rank, 48, 62, rank_color, 103,
                       align: :center, scale: pop)
        Px.text_shadow(Assets.tiny, RANK_WORDS.fetch(@result.rank, ""), 110, 172,
                       Palette::BONE, 103, align: :center)

        @result.skipped ? draw_skipped : draw_numbers(rank_color)

        Px.text_shadow(Assets.small, next_label, Config::W / 2, 214,
                       Palette.alpha(Palette::YELLOW, blinking_alpha), 103,
                       align: :center)

        Hud.draw(state, elapsed)
        Hud.draw_drowsiness(state)
      end

      private

      # 立ち絵は成績で選ぶ。A以上＝success / C以下＝fail / それ以外＝normal
      def draw_portrait
        sprite = @result.skipped ? Assets.portrait(:normal)
                                 : Assets.portrait_for_rank(@result.rank)
        return unless sprite

        bounce = @result.rank == "S" ? (Math.sin(elapsed * 6.0).abs * 4) : 0
        sprite.draw_sized(262, 208 - bounce, 150, 101)
      end

      # 数字はゆっくり伸ばしたほうが「削った」実感が出る。
      def reveal
        [elapsed / 0.7, 1.0].min
      end

      def draw_numbers(rank_color)
        x = 98
        Px.text_shadow(Assets.tiny, "達成率", x, 48, Palette::BONE, 103)
        Px.text_shadow(Assets.large, "#{(@result.performance * 100 * reveal).round} %",
                       x + 104, 42, rank_color, 103, align: :right)

        Px.text_shadow(Assets.tiny, "睡眠ゲージ削減", x, 72, Palette::BONE, 103)
        Px.text_shadow(Assets.huge, "-#{(@result.reward * reveal).round}",
                       x + 104, 64, Palette::GREEN, 103, align: :right)

        rows = [
          ["到達レベル", "Lv.#{@result.level}"],
          ["最大コンボ", "#{@result.max_combo}"],
          ["ミスで増えた眠気", "+#{@result.penalty.round}"]
        ]
        rows.each_with_index do |(label, value), i|
          y = 100 + i * 14
          Px.text_shadow(Assets.tiny, label, 22, y, Palette::BONE, 103)
          tone = i == 2 && @result.penalty >= 1 ? Palette::RED : Palette::WHITE
          Px.text_shadow(Assets.tiny, value, 202, y, tone, 103, align: :right)
        end

        draw_gauge_line
      end

      def draw_skipped
        Px.text_shadow(Assets.small, "見送った", 130, 62, Palette::SLATE, 103,
                       align: :center)
        Px.text_shadow(Assets.tiny, "削減 0 ／ ミス 0", 130, 84, Palette::BONE, 103,
                       align: :center)
        Px.text_shadow(Assets.tiny, "休んだぶん、眠気だけが進んだ。", 112, 112,
                       Palette::BONE, 103)
        draw_gauge_line
      end

      def draw_gauge_line
        Px.rect(22, 146, 180, 1, Palette::SLATE, 103)
        Px.text_shadow(Assets.tiny, "現在の睡眠ゲージ", 22, 152, Palette::BONE, 103)
        Px.text_shadow(Assets.small, "#{state.gauge.to_i} / 1000", 202, 150,
                       Palette.gauge_color(state.gauge.ratio), 103, align: :right)
      end

      def next_label
        state.day_finished? ? "SPACE で1日を終える" : "SPACE でつぎの枠へ"
      end

      def continue!
        return if @moved

        @moved = true
        if state.day_finished?
          goto(DayResult.new(window, state))
        else
          goto(MinigameIntro.new(window, state, state.current_kind))
        end
      end
    end
  end
end
