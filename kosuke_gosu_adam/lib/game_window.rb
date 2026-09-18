# frozen_string_literal: true

require 'gosu'
require_relative 'game_state'
require_relative 'minigames'
require_relative 'world'

module Kosuke
  class GameWindow < Gosu::Window
    WIDTH = 1120
    HEIGHT = 780
    BG = 0xff_111b26
    PANEL = 0xff_1d2c3a
    PAPER = 0xff_f1eadc
    INK = 0xff_172b35
    TEXT = 0xff_f2eddf
    MUTED = 0xff_afbec7
    MINT = 0xff_a6d6b4
    CORAL = 0xff_ec947e
    GOLD = 0xff_eec98a

    attr_reader :state, :world, :mini

    def initialize
      super(WIDTH, HEIGHT, resizable: false, update_interval: 1000.0 / 60)
      self.caption = '峰小輔の7日間 | Ruby + Gosu'
      @fonts = {}
      @font_name = find_font
      @portrait = load_portrait
      @buttons = []
      @button_phase = nil
      @toast = ''
      @toast_until = 0
      @last_ms = Gosu.milliseconds
      reset
    end

    def find_font
      candidates = [ENV['KOSUKE_FONT'],
                    File.expand_path('../assets/font.ttf', __dir__),
                    'C:/Windows/Fonts/meiryo.ttc',
                    'C:/Windows/Fonts/YuGothM.ttc',
                    '/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc',
                    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
                    '/usr/share/fonts/truetype/noto/NotoSansJP-Regular.ttf']
      candidates.compact.find { |path| File.file?(path) } || 'Noto Sans CJK JP'
    end

    def load_portrait
      path = File.expand_path('../assets/kosuke_reference.jpeg', __dir__)
      File.file?(path) ? Gosu::Image.new(path, retro: true) : nil
    end

    def reset
      @state = GameState.new
      @world = World.new
      @mini = nil
      @selected_difficulty = 1
      @buttons.clear
      @last_ms = Gosu.milliseconds
    end

    def font(size, bold = false)
      @fonts[[size, bold]] ||= Gosu::Font.new(size, name: @font_name, bold: bold)
    end

    def text(value, x, y, size = 20, color = TEXT, z = 100, bold: false)
      font(size, bold).draw_text(value.to_s, x, y, z, 1, 1, color)
    end

    def center(value, x, y, size = 20, color = TEXT, z = 100, bold: false)
      f = font(size, bold)
      f.draw_text(value.to_s, x - f.text_width(value.to_s) / 2.0, y, z, 1, 1, color)
    end

    def rect(x, y, w, h, color, z = 90)
      Gosu.draw_rect(x, y, w, h, color, z)
    end

    def panel(x, y, w, h, color = PANEL, z = 90)
      rect(x + 4, y + 5, w, h, 0x55_000000, z - 0.1)
      rect(x, y, w, h, color, z)
    end

    def button(id, label, x, y, w, h = 48, enabled: true, color: MINT, secondary: false)
      hovered = mouse_x.between?(x, x + w) && mouse_y.between?(y, y + h)
      fill = if !enabled then 0xff_34424d
             elsif secondary then hovered ? 0xff_405662 : 0xff_2c414e
             elsif hovered then 0xff_d2e9c6
             else color
             end
      rect(x, y + 3, w, h, 0xff_10202b, 120)
      rect(x, y, w, h, fill, 121)
      foreground = enabled ? (secondary ? TEXT : INK) : 0xff_8c9ca6
      center(label, x + w / 2, y + (h - 20) / 2, 20, foreground, 122, bold: true)
      @buttons << { id: id, x: x, y: y, w: w, h: h, enabled: enabled }
    end

    def held?(*ids)
      ids.any? { |id| Gosu.button_down?(id) }
    end

    def mouse_on?(id)
      held?(Gosu::MS_LEFT) && @buttons.any? do |b|
        b[:id] == id && b[:enabled] && mouse_x.between?(b[:x], b[:x] + b[:w]) &&
          mouse_y.between?(b[:y], b[:y] + b[:h])
      end
    end

    def update
      now = Gosu.milliseconds
      dt = [(now - @last_ms) / 1000.0, 0.1].min
      @last_ms = now
      advance_game([dt, 0].max)
    end

    # テストでも呼べる1ステップ。ゲーム時計とミニゲーム時計は同じdtを使う。
    def advance_game(dt)
      if @state.phase == :room
        step = @state.advance(dt)
        return unless @state.phase == :room
        horizontal = (held?(Gosu::KB_RIGHT, Gosu::KB_D) ? 1 : 0) - (held?(Gosu::KB_LEFT, Gosu::KB_A) ? 1 : 0)
        vertical = (held?(Gosu::KB_DOWN, Gosu::KB_S) ? 1 : 0) - (held?(Gosu::KB_UP, Gosu::KB_W) ? 1 : 0)
        reached = @world.update(step, horizontal: horizontal, vertical: vertical)
        open_activity(reached) if reached
      elsif @state.phase == :mini
        step = @state.advance([dt, @mini.remaining].min)
        return unless @state.phase == :mini
        @mini.update(step,
                     left: held?(Gosu::KB_LEFT, Gosu::KB_A) || mouse_on?(:left),
                     right: held?(Gosu::KB_RIGHT, Gosu::KB_D) || mouse_on?(:right))
        finish_if_done
      end
    end

    def finish_if_done
      @state.finish_minigame(@mini.quality) if @state.phase == :mini && @mini.done?
    end

    def notify(message)
      @toast = message
      @toast_until = Gosu.milliseconds + 2500
    end

    def request_activity(id)
      return unless @state.phase == :room
      unless @state.available?(id)
        message = @state.cooldown(id).positive? ? "この設備はあと#{@state.cooldown(id).ceil}秒で使えます" : 'もうすぐ1日の終わり。部屋で待とう。'
        notify(message)
        return
      end
      @world.go_to_station(id)
    end

    def open_activity(id)
      @selected_difficulty = 1
      @world.stop if @state.choose_activity(id)
    end

    def start_minigame(difficulty)
      return unless @state.begin_minigame(difficulty)
      @mini = Minigames::REGISTRY.fetch(@state.activity).new(difficulty)
      @last_ms = Gosu.milliseconds
    end

    def dispatch(action)
      case action
      when :start then @state.start
      when :training, :bath, :supplement then request_activity(action)
      when :easy, :normal, :hard then start_minigame(action)
      when :cancel then @state.cancel_choice
      when :continue then @state.return_to_room
      when :pause then @state.pause
      when :resume then @state.resume
      when :nap then @state.complete_day(nap: true); @world.stop
      when :skip_nap then @state.complete_day(nap: false); @world.stop
      when :restart then reset; @state.start
      when :quit then close
      when :action, :one, :two, :three, :four
        if @state.phase == :mini
          @mini.input(action)
          finish_if_done
        end
      end
      @last_ms = Gosu.milliseconds
    end

    def button_down(id)
      super
      update # 同フレームの1000到達を入力より先に判定する。
      if id == Gosu::KB_ESCAPE
        case @state.phase
        when :room, :mini then dispatch(:pause)
        when :paused then dispatch(:resume)
        when :choose then dispatch(:cancel)
        end
        return
      end
      if id == Gosu::MS_LEFT
        # 前画面のボタンに連続クリックが入るのを防ぐ。
        return unless @button_phase == @state.phase
        hit = @buttons.reverse.find do |b|
          b[:enabled] && mouse_x.between?(b[:x], b[:x] + b[:w]) && mouse_y.between?(b[:y], b[:y] + b[:h])
        end
        return dispatch(hit[:id]) if hit
        if @state.phase == :room && mouse_x.between?(24, 784) && mouse_y.between?(176, 646)
          point = World.unproject((mouse_x - 24) / 2.0, (mouse_y - 176) / 2.0)
          @world.go_to(*point)
        end
        return
      end
      number = [Gosu::KB_1, Gosu::KB_2, Gosu::KB_3, Gosu::KB_4].index(id)
      enter = [Gosu::KB_RETURN, Gosu::KB_SPACE].include?(id)
      case @state.phase
      when :title then dispatch(:start) if enter
      when :room
        request_activity(%i[training bath supplement][number]) if number && number < 3
        open_activity(@world.nearby) if id == Gosu::KB_E && @world.nearby
      when :choose
        if number && number < 3
          dispatch(%i[easy normal hard][number])
        elsif id == Gosu::KB_LEFT
          @selected_difficulty = (@selected_difficulty - 1) % 3
        elsif id == Gosu::KB_RIGHT
          @selected_difficulty = (@selected_difficulty + 1) % 3
        elsif enter
          dispatch(%i[easy normal hard][@selected_difficulty])
        end
      when :mini
        dispatch(:action) if id == Gosu::KB_SPACE
        dispatch(%i[one two three four][number]) if number
      when :result then dispatch(:continue) if enter
      when :day_clear
        dispatch(:nap) if enter
        dispatch(:skip_nap) if id == Gosu::KB_N
      when :paused
        dispatch(:resume) if enter
        dispatch(:restart) if id == Gosu::KB_R
        dispatch(:quit) if id == Gosu::KB_Q
      when :game_over, :victory then dispatch(:restart) if enter
      end
    end

    def lose_focus
      @state.pause
      @last_ms = Gosu.milliseconds
    end

    def gain_focus
      @last_ms = Gosu.milliseconds
    end

    def needs_cursor?
      true
    end

    def draw
      @buttons.clear
      @button_phase = @state.phase
      rect(0, 0, WIDTH, HEIGHT, BG, -10)
      draw_header
      draw_room
      draw_sidebar
      draw_activities
      draw_footer
      case @state.phase
      when :title then draw_title
      when :choose then draw_choice
      when :mini then draw_minigame
      when :result then draw_result
      when :day_clear then draw_day_clear
      when :paused then draw_pause
      when :game_over, :victory then draw_ending
      end
    end

    def gauge_color
      return CORAL if @state.gauge >= 800
      return GOLD if @state.gauge >= 500
      MINT
    end

    def draw_header
      text('KOSUKE / WEEK SURVIVAL', 26, 12, 13, MINT)
      text('峰小輔の 7日間', 24, 33, 34, TEXT, 100, bold: true)
      text('DOT ROOM  /  PROTOTYPE 01', 738, 28, 13, MUTED)
      button(:pause, 'II  休止', 1010, 22, 86, 40, secondary: true) if @state.running?
      rect(24, 85, 1072, 1, 0xff_344653)
      text('睡眠・気絶ゲージ', 24, 99, 18, TEXT)
      text(format('%04d', @state.gauge.floor), 567, 93, 28, gauge_color, 100, bold: true)
      text('/ 1000', 650, 106, 14, MUTED)
      rect(24, 128, 748, 14, 0xff_34434b)
      rect(24, 128, 748 * @state.gauge / Balance::MAX_GAUGE, 14, gauge_color, 91)
      19.times { |i| rect(24 + (i + 1) * 37.4, 128, 2, 14, BG, 92) }
      text('0  通常', 24, 147, 12, MUTED)
      text('1000  強制睡眠', 675, 147, 12, MUTED)
      text("DAY  #{format('%02d', @state.day)} / 07", 811, 96, 20, MINT, 100, bold: true)
      text(@state.clock, 996, 96, 24, TEXT, 100, bold: true)
      7.times do |i|
        color = i < @state.history.length ? MINT : (i == @state.day - 1 ? GOLD : 0xff_34434b)
        rect(812 + i * 40, 134, 32, 7, color)
      end
      text(@state.running? ? '時間経過中' : '時間停止中', 811, 148, 12, MUTED)
    end

    def draw_room
      @scene = @world.render
      @scene.draw(24, 176, 10, 2, 2)
      text('ROOM 01', 44, 195, 13, MUTED, 20)
      World::STATIONS.each do |id, station|
        sx, sy = World.project(*station[:label], 29)
        sx = 24 + sx * 2
        sy = 176 + sy * 2
        label = "#{station[:number]}  #{Balance::ACTIVITIES[id][:label]}"
        w = font(14).text_width(label) + 18
        rect(sx - w / 2, sy - 17, w, 25, 0xdd_152735, 21)
        center(label, sx, sy - 13, 14, Balance::ACTIVITIES[id][:color], 22)
      end
      hint = @world.nearby
      if hint && @state.phase == :room
        center("E で#{Balance::ACTIVITIES[hint][:label]}", 404, 612, 16, TEXT, 22)
      else
        center('床をクリックして移動', 404, 612, 14, MUTED, 22)
      end
      if Gosu.milliseconds < @toast_until && @state.phase == :room
        rect(70, 565, 666, 34, 0xee_162934, 23)
        center(@toast, 403, 572, 17, GOLD, 24)
      end
    end

    def draw_sidebar
      panel(808, 176, 288, 470)
      text('PLAYER 01', 832, 194, 12, MINT)
      text('峰 小輔', 832, 216, 27, TEXT, 100, bold: true)
      rect(834, 258, 236, 229, PAPER)
      if @portrait
        ratio = 219.0 / @portrait.height
        @portrait.draw(952 - @portrait.width * ratio / 2, 263, 96, ratio, ratio)
      end
      text('SUCCESS', 832, 511, 12, MUTED)
      text(format('%02d', @state.successes), 1008, 497, 32, MINT, 100, bold: true)
      text("今日のゲージ増加  +#{Balance::DAILY_GAIN[@state.day - 1]}", 832, 553, 16, TEXT)
      text('1日クリアで 30分の仮眠', 832, 588, 16, MUTED)
      text('ゲージ −30 / 下限 0', 832, 613, 14, MINT)
    end

    def draw_activities
      Balance::ACTIVITIES.each_with_index do |(id, data), index|
        x = 24 + index * 260
        panel(x, 667, 248, 68)
        rect(x, 667, 4, 68, data[:color], 91)
        text("0#{index + 1}", x + 16, 680, 23, data[:color], 100, bold: true)
        text(data[:label], x + 59, 677, 22, TEXT, 100, bold: true)
        label = @state.cooldown(id).positive? ? "あと #{@state.cooldown(id).ceil} 秒" : data[:title]
        text(label, x + 60, 710, 13, MUTED)
        if @state.phase == :room
          @buttons << { id: id, x: x, y: 667, w: 248, h: 68, enabled: true }
        end
      end
      text('1日 = 約90秒', 842, 679, 20, GOLD)
      text('7日目を乗り切れば勝利', 823, 710, 15, MUTED)
    end

    def draw_footer
      text('移動  WASD / 矢印 / クリック     決定  E / ENTER     設備  1・2・3     休止  ESC', 24, 752, 13, MUTED)
    end

    def overlay
      @buttons.select! { |b| b[:id] == :pause && @state.running? }
      rect(0, 172, WIDTH, HEIGHT - 172, 0xc8_0b1520, 105)
    end

    def draw_title
      overlay
      panel(124, 199, 872, 459, PAPER, 110)
      text('A SMALL ROOM. A LONG WEEK.', 165, 228, 14, 0xff_426b62, 115)
      text('峰小輔の', 161, 268, 45, INK, 115, bold: true)
      text('7日間', 160, 316, 91, INK, 115, bold: true)
      text('ミニゲームで眠気をかわそう。', 165, 438, 23, INK, 115)
      text('1000で強制睡眠。7日間を乗り切れば勝利！', 165, 477, 18, INK, 115)
      text('筋トレ  /  お風呂  /  星粒メモリー', 165, 512, 16, 0xff_557077, 115)
      button(:start, 'START   /   ENTER', 165, 558, 353, 56)
      if @portrait
        ratio = 328.0 / @portrait.height
        @portrait.draw(722, 227, 116, ratio, ratio)
      end
      text('架空キャラクターのゲームです。', 675, 567, 15, INK, 115)
      text('睡眠・サプリの効果はゲーム専用。', 655, 592, 15, INK, 115)
    end

    def draw_choice
      overlay
      data = Balance::ACTIVITIES.fetch(@state.activity)
      panel(176, 212, 768, 432, PANEL, 110)
      text(data[:label], 212, 240, 14, data[:color], 115)
      text(data[:title], 212, 271, 32, TEXT, 115, bold: true)
      data[:instructions].each_with_index { |line, i| text(line, 212, 328 + i * 29, 19, MUTED, 115) }
      Balance::DIFFICULTIES.each_with_index do |(key, rule), i|
        x = 210 + i * 231
        selected = @selected_difficulty == i
        rect(x, 410, 214, 137, selected ? 0xff_355344 : 0xff_293b49, 115)
        center("#{i + 1}  #{rule[:label]}", x + 107, 425, 20, TEXT, 116, bold: true)
        center("−#{rule[:min]} 〜 −#{rule[:max]}", x + 107, 465, 25, MINT, 116, bold: true)
        center("成功ライン #{(rule[:threshold] * 100).round}%", x + 107, 510, 14, MUTED, 116)
        @buttons << { id: key, x: x, y: 410, w: 214, h: 137, enabled: true }
      end
      text('難易度を選ぶと開始。説明中は時間が止まります。', 212, 565, 16, MUTED, 116)
      button(:cancel, '部屋へ戻る / ESC', 614, 592, 294, 36, secondary: true)
    end

    def draw_minigame
      overlay
      data = Balance::ACTIVITIES.fetch(@state.activity)
      panel(144, 206, 832, 470, PANEL, 110)
      text("#{data[:label]}  /  #{Balance::DIFFICULTIES[@state.difficulty][:label]}", 182, 229, 16, data[:color], 115)
      text(data[:title], 182, 264, 31, TEXT, 115, bold: true)
      text(format('%.1f s', @mini.remaining), 838, 252, 29, GOLD, 115, bold: true)
      rect(182, 314, 756, 6, 0xff_354951, 115)
      rect(182, 314, 756 * @mini.remaining / Balance::MINI_SECONDS, 6, data[:color], 116)
      case @mini
      when Minigames::Training then draw_training_game
      when Minigames::Bath then draw_bath_game
      when Minigames::Supplement then draw_supplement_game
      end
      text('プレイ中もゲージが増加します', 182, 646, 14, MUTED, 116)
      button(:pause, 'II', 886, 625, 52, 34, secondary: true)
    end

    def lane(x, y, width, position, target, half_width, accent)
      rect(x, y, width, 32, 0xff_314650, 115)
      rect(x + (target - half_width) * width, y, half_width * 2 * width, 32, 0xff_50776c, 116)
      rect(x + target * width - 1, y - 8, 2, 48, MINT, 117)
      rect(x + position * width - 6, y - 10, 12, 52, accent, 118)
    end

    def draw_training_game
      center('中央を狙って、5回リフト！', 560, 344, 20, TEXT, 116)
      lane(244, 439, 632, @mini.marker, 0.5, @mini.half_width, GOLD)
      @mini.scores.each_with_index do |score, index|
        color = score >= 0.55 ? MINT : CORAL
        rect(410 + index * 64, 393, 44, 10, color, 117)
      end
      center("#{@mini.scores.length} / 5    #{@mini.feedback}", 560, 501, 23, GOLD, 116, bold: true)
      button(:action, 'LIFT!   /   SPACE', 349, 553, 422, 57, color: GOLD)
    end

    def draw_bath_game
      center('泡を光るゾーンに保とう', 560, 343, 21, TEXT, 116)
      center(@mini.feedback, 560, 387, 29, @mini.inside? ? MINT : GOLD, 116, bold: true)
      lane(244, 444, 632, @mini.position, @mini.target, @mini.half_width, 0xff_96d6db)
      button(:left, '←  左へ / A', 268, 548, 273, 57, color: 0xff_96d6db)
      button(:right, '右へ / D  →', 579, 548, 273, 57, color: 0xff_96d6db)
      center('ボタン・キーを押している間、泡が動きます', 560, 509, 16, MUTED, 116)
    end

    def draw_supplement_game
      title = @mini.revealing? ? '光る順番を覚えよう' : '同じ順番で選ぼう'
      center(title, 560, 350, 25, TEXT, 116, bold: true)
      labels = ['1  星', '2  月', '3  花', '4  空']
      colors = [GOLD, 0xff_b4a0df, MINT, 0xff_87c8d4]
      labels.each_with_index do |label, i|
        x = 231 + i * 171
        lit = @mini.lit_index == i
        fill = lit ? colors[i] : 0xff_344653
        rect(x, 420, 150, 103, fill, 117)
        center(label, x + 75, 453, 28, lit ? INK : TEXT, 118, bold: true)
        @buttons << { id: %i[one two three four][i], x: x, y: 420, w: 150, h: 103,
                      enabled: !@mini.revealing? }
      end
      center("#{@mini.answers.length} / #{@mini.sequence.length}", 560, 550, 28, MINT, 118, bold: true)
      center('架空の星粒を並べるミニゲーム', 560, 603, 16, MUTED, 118)
    end

    def draw_result
      overlay
      result = @state.last_result
      success = result[:reward].positive?
      panel(247, 215, 626, 434, PAPER, 110)
      center(success ? 'MINIGAME CLEAR' : 'TRY AGAIN', 560, 243, 19, INK, 115, bold: true)
      center(result[:grade], 560, 277, 79, success ? 0xff_39745e : 0xff_9c574c, 115, bold: true)
      center("成功度 #{(result[:quality] * 100).round}%", 560, 380, 23, INK, 115)
      center("獲得効果  −#{result[:reward]}", 560, 421, 32, INK, 115, bold: true)
      center("実際の減少 −#{result[:actual].round(1)}  /  現在 #{@state.gauge.floor}", 560, 471, 18, INK, 115)
      center('ゲージが0未満になる分は切り捨てます', 560, 513, 15, 0xff_526a6b, 115)
      button(:continue, '部屋へ戻る  /  ENTER', 338, 567, 444, 53)
    end

    def draw_day_clear
      overlay
      panel(210, 213, 700, 439, PAPER, 110)
      center("DAY #{format('%02d', @state.day)} CLEAR", 560, 247, 35, INK, 115, bold: true)
      center('30分の仮眠ができる！', 560, 315, 30, INK, 115, bold: true)
      center("#{@state.gauge.floor} → #{[@state.gauge - Balance::NAP_REDUCTION, 0].max.floor}", 560, 374, 52, 0xff_39745e, 115, bold: true)
      center('23:30 → 24:00  /  ゲージ −30（下限0）', 560, 445, 20, INK, 115)
      next_label = @state.day == 7 ? '30分眠って、結果へ / ENTER' : '30分眠って、翌日へ / ENTER'
      button(:nap, next_label, 286, 512, 548, 53)
      button(:skip_nap, '仮眠せずに進む / N', 383, 590, 354, 39, secondary: true)
    end

    def draw_pause
      overlay
      panel(324, 246, 472, 345, PANEL, 110)
      center('PAUSED', 560, 280, 43, MINT, 115, bold: true)
      center('時間とゲージは止まっています', 560, 344, 18, MUTED, 115)
      button(:resume, '再開 / ESC・ENTER', 380, 397, 360, 49)
      button(:restart, '最初から / R', 380, 466, 360, 41, secondary: true)
      button(:quit, 'ゲームを閉じる / Q', 380, 526, 360, 38, secondary: true)
    end

    def draw_ending
      overlay
      won = @state.phase == :victory
      panel(196, 207, 728, 459, won ? PAPER : PANEL, 110)
      ink = won ? INK : TEXT
      center(won ? 'WEEK COMPLETE' : 'Z z z ...', 560, 234, 21, won ? 0xff_39745e : MUTED, 115)
      center(won ? '7日間クリア！' : '強制睡眠', 560, 282, 53, ink, 115, bold: true)
      center(won ? '峰小輔、おつかれさま。' : 'ゲージが1000になりました。', 560, 363, 24, ink, 115)
      center("到達 #{@state.day}日目   /   成功 #{@state.successes}回   /   仮眠 #{@state.nap_count}回", 560, 413, 20, ink, 115)
      center("ミニゲームでの総減少 #{@state.total_reduction.round} ポイント", 560, 454, 18, ink, 115)
      if won
        @state.history.each_with_index do |entry, index|
          x = 279 + index * 83
          rect(x, 504, 64, 48, 0xff_d4decc, 115)
          center("D#{entry[:day]}", x + 32, 508, 13, INK, 116)
          center(entry[:gauge].floor, x + 32, 528, 16, INK, 116, bold: true)
        end
      end
      button(:restart, 'もう一度 / ENTER', 344, 587, 432, 49)
    end
  end
end
