# frozen_string_literal: true

require_relative 'game_window'
require_relative 'stream_feed'
require_relative 'hallucinations'
require_relative 'animation'

module Kosuke
  # 進行ルールは従来のGameWindow/GameStateと共有し、配信の見え方を追加する。
  class StreamWindow < GameWindow
    PLUM = 0xff_292139
    LAVENDER = 0xff_c7b8fa
    PINK = 0xff_f3a9d0
    PALE = 0xff_f3e9fa
    SOFT = 0xff_beb0ce
    GLOBAL_BUTTONS = %i[toggle_view toggle_comments toggle_gentle].freeze
    ACTOR_BOX = [170, 341, 290, 282].freeze
    MINI_SCALE = 760.0 / 832
    MINI_SHIFT = 24 - 144 * MINI_SCALE

    attr_reader :feed, :hallucinations, :visual_time, :viewer_mode, :comments_enabled, :gentle

    def font(size, bold = false)
      super((size * 1.18).round, bold)
    end

    def mouse_x
      value = super
      @drawing_mini ? (value - MINI_SHIFT) / MINI_SCALE : value
    end

    def initialize
      super
      self.caption = '峰小輔の7日間 ─ LIVE edition | Ruby + Gosu'
      assets = File.expand_path('../assets', __dir__)
      # 隣のポーズにかかる足先と、境界1pxの断片をアトラス座標で補正する。
      adjustments = (0..3).to_h { |col| [[3, col], [0, 2, 0, 0]] }
      adjustments[[4, 1]] = [0, 0, 12, 0]
      adjustments[[4, 2]] = [12, 0, 0, 0]
      @actions = SpriteAtlas.new(File.join(assets, 'action_sprites.png'), columns: 4, rows: 5, rect_adjustments: adjustments)
      @kuiya = SpriteAtlas.new(File.join(assets, 'kuiya_sprites.png'), columns: 2, rows: 2)
    end

    def reset
      super
      @feed = StreamFeed.new
      @hallucinations = Hallucinations.new
      @visual_time = 0.0
      @viewer_mode = true if @viewer_mode.nil?
      @comments_enabled = true if @comments_enabled.nil?
      @gentle = false if @gentle.nil?
      @observed_phase = :title
      @observed_mini = nil
      @observed_event = 0
      @observed_level = 0
      @bath_inside = nil
    end

    def advance_game(dt)
      was_paused = @state.phase == :paused
      super
      return if was_paused
      @visual_time += dt
      @hallucinations.update(dt, gauge: @state.gauge)
      observe_events
      @feed.viewport(@state.phase == :mini ? ACTOR_BOX[2] : 760)
      @feed.update(dt, ambient: %i[room mini choose result].include?(@state.phase))
    end

    def start_minigame(difficulty)
      super
      observe_events
    end

    def observe_events
      if @mini && @mini.object_id != @observed_mini
        @observed_mini = @mini.object_id
        @observed_event = 0
        @bath_inside = nil
      end
      if @mini && @mini.event_serial > @observed_event
        event = @mini.last_event
        key = case event[:kind]
              when :training_hit then event[:score] >= 0.55 ? :training_hit : :training_miss
              when :memory_answer then event[:correct] ? :memory_ok : :memory_miss
              when :massage_reaction then event[:score].positive? ? :massage_ok : :massage_miss
              when :camera_catch then event[:score].positive? ? :camera_ok : :camera_miss
              end
        @feed.emit(key, throttle: 0.5) if key
        @observed_event = @mini.event_serial
      end
      if @state.phase == :mini && @mini.is_a?(Minigames::Bath) && @mini.inside? != @bath_inside
        @bath_inside = @mini.inside?
        @feed.emit(@bath_inside ? :bath_keep : :bath_miss, throttle: 1.5)
      end
      if @state.phase != @observed_phase
        event = case @state.phase
                when :mini
                  @feed.begin_activity(@state.activity) unless @observed_phase == :paused
                  nil
                when :result then @state.last_result[:reward].positive? ? :clear : :miss
                when :day_clear, :game_over, :victory then @state.phase
                end
        @feed.emit(event) if event
        @observed_phase = @state.phase
      end
      level = Hallucinations.level_for(@state.gauge)
      @feed.emit(level >= 2 ? :danger : :sleepy) if level > @observed_level
      @observed_level = level
    end

    def dispatch(action)
      before = @state.phase
      case action
      when :massage, :camera then request_activity(action)
      when :five, :six, :left, :right
        if @state.phase == :mini
          @mini.input(action)
          finish_if_done
        end
      when :toggle_view then @viewer_mode = !@viewer_mode
      when :toggle_comments then @comments_enabled = !@comments_enabled
      when :toggle_gentle then @gentle = !@gentle
      when :repel
        @feed.emit(:repel) if @state.running? && @hallucinations.repel
      else super
      end
      @feed.emit(:nap) if action == :nap && before == :day_clear
      @hallucinations.update(0, gauge: @state.gauge)
      observe_events
      @last_ms = Gosu.milliseconds
    end

    def button_down(id)
      special = { Gosu::KB_C => :toggle_comments, Gosu::KB_V => :toggle_view,
                  Gosu::KB_H => :toggle_gentle, Gosu::KB_9 => :repel }[id]
      if special
        update
        dispatch(special)
        return
      end
      if @state.phase == :room && [Gosu::KB_4, Gosu::KB_5].include?(id)
        update
        dispatch(id == Gosu::KB_4 ? :massage : :camera)
        return
      end
      if @state.phase == :mini
        action = if @mini.is_a?(Minigames::Massage)
                   :left if [Gosu::KB_LEFT, Gosu::KB_A].include?(id)
                 end
        action = :right if @mini.is_a?(Minigames::Massage) && [Gosu::KB_RIGHT, Gosu::KB_D].include?(id)
        action = :five if @mini.is_a?(Minigames::Camera) && id == Gosu::KB_5
        action = :six if @mini.is_a?(Minigames::Camera) && id == Gosu::KB_6
        if action
          update
          dispatch(action)
          return
        end
      end
      super
    end

    def draw_header
      rect(0, 0, WIDTH, 172, PLUM, 0)
      rect(0, 0, WIDTH, 26, LAVENDER, 1)
      text('KOSUKE.LIVE  /  7 DAYS SURVIVAL', 24, 5, 12, PLUM, 100, bold: true)
      text('−     □     ×', 1008, 2, 17, PLUM, 100)
      text('峰小輔の 7日間', 24, 38, 32, PALE, 100, bold: true)
      text(@viewer_mode ? 'LIVE edition  /  見守り配信中' : 'ROOM edition  /  プレイヤー視点', 316, 56, 13, PINK)
      button(:toggle_view, @viewer_mode ? 'V 視聴者' : 'V プレイヤー', 668, 40, 128, 34, color: LAVENDER)
      button(:toggle_comments, @comments_enabled ? 'C コメ ON' : 'C コメ OFF', 806, 40, 128, 34, color: PINK)
      button(:pause, 'II 休止', 1010, 40, 86, 34, secondary: true) if @state.running?
      button(:toggle_gentle, @gentle ? 'H 弱' : 'H 通常', 944, 40, 58, 34, color: PALE)
      rect(24, 85, 1072, 1, 0xff_594769)
      text('睡眠・気絶ゲージ', 24, 98, 18, PALE)
      text("自然増加 ×#{Balance::GAUGE_SPEED_MULTIPLIER}", 207, 101, 13, SOFT)
      text(format('%04d', @state.gauge.floor), 567, 93, 28, gauge_color, 100, bold: true)
      text('/ 1000', 650, 105, 14, SOFT)
      rect(24, 128, 748, 14, 0xff_493b59)
      rect(24, 128, 748 * @state.gauge / Balance::MAX_GAUGE, 14, gauge_color, 91)
      19.times { |i| rect(24 + (i + 1) * 37.4, 128, 2, 14, PLUM, 92) }
      text('0 通常', 24, 147, 12, SOFT)
      ghost_hint = @state.gauge >= 550 ? 'クイヤ出現中  /  9で追い払う' : '550から何か見える…'
      text(ghost_hint, 280, 147, 12, @state.gauge >= 550 ? PINK : SOFT)
      text('1000 強制睡眠', 682, 147, 12, SOFT)
      text("DAY #{format('%02d', @state.day)} / 07", 811, 96, 20, LAVENDER, 100, bold: true)
      text(@state.clock, 996, 96, 24, PALE, 100, bold: true)
      7.times do |i|
        color = i < @state.history.length ? MINT : (i == @state.day - 1 ? PINK : 0xff_493b59)
        rect(812 + i * 40, 134, 32, 7, color)
      end
      text(@state.running? ? 'ON AIR  /  時間経過中' : '時間停止中', 811, 148, 12, SOFT)
    end

    def draw_room
      super
      return unless @viewer_mode
      rect(24, 176, 760, 29, LAVENDER, 30)
      text('● LIVE   峰小輔の部屋', 36, 182, 14, PLUM, 32, bold: true)
      text('CAM 01    ▪ ▪ ▪', 652, 182, 13, PLUM, 32)
      if @state.phase == :room
        draw_hallucinations(24, 214, 760, 379, 32)
        draw_comments(24, 218, 760, 157, 37)
        rect(40, 573, 175, 25, 0xdd_30283e, 33)
        text('架空の配信を視聴中', 50, 577, 13, PALE, 34)
      end
    end

    def draw_sidebar
      return super unless @viewer_mode
      panel(808, 176, 288, 470, PLUM)
      rect(808, 176, 288, 29, PINK, 91)
      text('LIVE CHAT', 824, 181, 15, PLUM, 100, bold: true)
      text('ゲーム内コメント', 960, 184, 11, PLUM)
      text('峰 小輔', 828, 220, 24, PALE, 100, bold: true)
      text('7日間、見守って。', 830, 255, 14, SOFT)
      text("SUCCESS #{format('%02d', @state.successes)}", 830, 280, 13, MINT)
      @actions&.draw(0, 3, 1045, 260, 88, 100)
      rect(826, 312, 252, 1, 0xff_594769)
      @feed.history.last(5).each_with_index do |entry, i|
        y = 328 + i * 47
        text(entry[:author], 828, y, 11, i.even? ? LAVENDER : PINK)
        text(entry[:text], 828, y + 17, 15, PALE)
      end
      rect(826, 571, 252, 1, 0xff_594769)
      text("今日の自然増加 +#{Balance::DAILY_GAIN[@state.day - 1]}", 828, 584, 14, SOFT)
      text('1日クリア → 30分仮眠 / −30', 828, 611, 14, MINT)
    end

    def draw_activities
      Balance::ACTIVITIES.each_with_index do |(id, data), i|
        x = 24 + i * 216
        panel(x, 664, 208, 72, PLUM)
        rect(x, 664, 208, 3, data[:color], 91)
        text("#{i + 1}", x + 12, 681, 28, data[:color], 100, bold: true)
        text(data[:label], x + 46, 678, 19, PALE, 100, bold: true)
        ready = @state.cooldown(id)
        label = ready.positive? ? "再使用まで #{ready.ceil}秒" : data[:title]
        text(label, x + 46, 711, 12, SOFT)
        if @state.phase == :room
          @buttons << { id: id, x: x, y: 664, w: 208, h: 72, enabled: true }
        end
      end
    end

    def draw_footer
      rect(0, 743, WIDTH, 37, PLUM, 90)
      text('移動 WASD / 矢印 / クリック    設備 1〜5    決定 E / ENTER    休止 ESC    コメント C    視点 V    演出 H    クイヤ 9', 24, 753, 13, SOFT)
    end

    def overlay
      @buttons.select! { |b| GLOBAL_BUTTONS.include?(b[:id]) || (b[:id] == :pause && @state.running?) }
      if @state.phase == :mini
        rect(0, 172, 796, HEIGHT - 172, 0xd5_1b1327, 105)
        rect(796, 647, WIDTH - 796, HEIGHT - 647, 0xd5_1b1327, 105)
      else
        rect(0, 172, WIDTH, HEIGHT - 172, 0xd5_1b1327, 105)
      end
    end

    def draw_title
      overlay
      panel(124, 199, 872, 459, PALE, 110)
      rect(124, 199, 872, 29, LAVENDER, 111)
      text('WELCOME TO KOSUKE.LIVE', 143, 205, 13, PLUM, 115, bold: true)
      text('LIVE / 7 DAYS', 165, 252, 16, 0xff_8e4775, 115, bold: true)
      text('峰小輔の', 159, 282, 44, PLUM, 115, bold: true)
      text('7日間', 155, 330, 80, PLUM, 115, bold: true)
      text('配信は、まだ終わらない。', 165, 435, 23, PLUM, 115, bold: true)
      text('5つのミニゲームで眠気をかわそう。', 165, 477, 18, PLUM, 115)
      text('1000で強制睡眠。7日間を乗り切れば勝利！', 165, 506, 17, PLUM, 115)
      button(:start, '配信スタート  /  ENTER', 165, 553, 386, 55, color: PINK)
      @actions&.draw(0, 2 + ((@visual_time * 3).floor % 2), 780, 403, 296, 116)
      text('架空のキャラクターと配信のゲーム', 650, 577, 15, PLUM, 115)
      text('睡眠・サプリの効果はゲーム専用', 650, 602, 14, 0xff_746281, 115)
    end

    def draw_choice
      overlay
      data = Balance::ACTIVITIES.fetch(@state.activity)
      panel(144, 206, 832, 452, PLUM, 110)
      rect(144, 206, 832, 29, data[:color], 111)
      text('SELECT DIFFICULTY', 165, 213, 12, PLUM, 115, bold: true)
      text(data[:title], 182, 257, 31, PALE, 115, bold: true)
      data[:instructions].each_with_index { |line, i| text(line, 182, 313 + i * 29, 18, SOFT, 115) }
      Balance::DIFFICULTIES.each_with_index do |(key, rule), i|
        x = 182 + i * 259
        selected = @selected_difficulty == i
        rect(x, 396, 238, 141, selected ? 0xff_605074 : 0xff_3c304f, 115)
        rect(x, 396, 238, 3, selected ? PINK : LAVENDER, 116)
        center("#{i + 1}  #{rule[:label]}", x + 119, 414, 20, PALE, 117, bold: true)
        center("−#{rule[:min]} 〜 −#{rule[:max]}", x + 119, 455, 26, MINT, 117, bold: true)
        center("成功ライン #{(rule[:threshold] * 100).round}%", x + 119, 504, 14, SOFT, 117)
        @buttons << { id: key, x: x, y: 396, w: 238, h: 141, enabled: true }
      end
      text('選ぶと開始。説明中は時間が止まります。', 182, 564, 16, SOFT, 116)
      button(:cancel, '部屋へ戻る / ESC', 638, 597, 300, 37, secondary: true)
    end

    def draw_minigame
      overlay
      first_button = @buttons.length
      begin
        @drawing_mini = true
        Gosu.translate(MINI_SHIFT, 0) do
          Gosu.scale(MINI_SCALE, 1) { draw_minigame_content }
        end
      ensure
        @drawing_mini = false
      end
      # 描画と同じ変換をマウスの当たり判定にも適用する。
      @buttons[first_button..].each do |button|
        button[:x] = MINI_SHIFT + button[:x] * MINI_SCALE
        button[:w] *= MINI_SCALE
      end
    end

    def draw_minigame_content
      data = Balance::ACTIVITIES.fetch(@state.activity)
      panel(144, 206, 832, 470, PLUM, 110)
      rect(144, 206, 832, 28, data[:color], 111)
      text('● LIVE   /   ACTION CAM', 165, 212, 12, PLUM, 115, bold: true)
      text(Balance::DIFFICULTIES[@state.difficulty][:label], 847, 211, 13, PLUM, 115)
      text(data[:title], 174, 257, 30, PALE, 115, bold: true)
      text(format('%.1f s', @mini.remaining), 842, 258, 27, PINK, 115, bold: true)
      rect(174, 313, 770, 6, 0xff_493b59, 115)
      rect(174, 313, 770 * @mini.remaining / Balance::MINI_SECONDS, 6, data[:color], 116)
      draw_actor
      case @mini
      when Minigames::Training then draw_training_game
      when Minigames::Bath then draw_bath_game
      when Minigames::Supplement then draw_supplement_game
      when Minigames::Massage then draw_massage_game
      when Minigames::Camera then draw_camera_game
      end
      text('プレイ中もゲージ上昇  /  クイヤは 9 で退散', 174, 646, 13, SOFT, 116)
      button(:pause, 'II', 888, 635, 56, 28, secondary: true)
    end

    def draw_actor
      x, y, w, h = ACTOR_BOX
      rect(x, y, w, h, 0xff_403651, 115)
      7.times { |i| rect(x, y + i * 40, w, 1, 0xff_4a3e5b, 116) }
      8.times { |i| rect(x + i * 40, y, 1, h, 0xff_4a3e5b, 116) }
      rect(x, y + h - 53, w, 53, 0xff_554362, 116)
      frame = Animation.frame(@state.activity, @mini)
      bob = @gentle ? 0 : Math.sin(@mini.time * 6) * 2
      @actions.draw(Animation::ROWS.fetch(@state.activity), frame, x + w / 2, y + h / 2 + 8 + bob, 266, 117, clip: ACTOR_BOX)
      if @state.activity == :camera && @mini.last_event && @mini.last_event[:score].zero? &&
         @mini.time - @mini.last_event[:at] < 0.65
        rect(x + 25, y + 194, w - 50, 42, 0xee_c7b8fa, 119)
        center('しばらくお待ちください', x + w / 2, y + 204, 17, PLUM, 120, bold: true)
      end
      draw_hallucinations(x, y + 28, w, h - 38, 121)
      draw_comments(x, y + 32, w, 120, 124) if @viewer_mode
      rect(x + 8, y + 8, 114, 22, PINK, 125)
      text('峰小輔 / LIVE', x + 15, y + 12, 12, PLUM, 126, bold: true)
      if @hallucinations.visible?
        text('…クイヤ？  [9]', x + 158, y + h - 22, 12, PINK, 126)
      end
    end

    def draw_training_game
      center('中央で 5回リフト！', 716, 350, 21, PALE, 116, bold: true)
      5.times do |i|
        score = @mini.scores[i]
        rect(554 + i * 66, 400, 43, 9, score ? (score >= 0.55 ? MINT : PINK) : 0xff_584766, 116)
      end
      lane(500, 448, 428, @mini.marker, 0.5, @mini.half_width, GOLD)
      center("#{@mini.scores.length} / 5   #{@mini.feedback}", 716, 503, 20, GOLD, 116, bold: true)
      button(:action, 'LIFT!   /   SPACE', 500, 554, 428, 56, color: GOLD)
    end

    def draw_bath_game
      center('泡を光るゾーンに保とう', 716, 350, 20, PALE, 116, bold: true)
      center(@mini.feedback, 716, 391, 25, @mini.inside? ? MINT : PINK, 116, bold: true)
      lane(500, 456, 428, @mini.position, @mini.target, @mini.half_width, 0xff_96d6db)
      center('キー・ボタンを押し続けて移動', 716, 510, 15, SOFT, 116)
      button(:left, '← 左 / A', 500, 554, 207, 56, color: 0xff_96d6db)
      button(:right, '右 / D →', 721, 554, 207, 56, color: 0xff_96d6db)
    end

    def draw_supplement_game
      title = @mini.revealing? ? '光る順番を覚えよう' : '同じ順番で選ぼう'
      center(title, 716, 351, 23, PALE, 116, bold: true)
      colors = [GOLD, LAVENDER, MINT, 0xff_87c8d4]
      ['1 星', '2 月', '3 花', '4 空'].each_with_index do |label, i|
        x = 500 + i * 110
        lit = @mini.lit_index == i
        fill = lit ? colors[i] : 0xff_574764
        rect(x, 426, 98, 104, fill, 117)
        center(label, x + 49, 461, 25, lit ? PLUM : PALE, 118, bold: true)
        @buttons << { id: %i[one two three four][i], x: x, y: 426, w: 98, h: 104, enabled: !@mini.revealing? }
      end
      center("#{@mini.answers.length} / #{@mini.sequence.length}", 716, 555, 27, MINT, 118, bold: true)
      center('架空の星粒を並べるミニゲーム', 716, 603, 14, SOFT, 118)
    end

    def draw_massage_game
      target = @mini.active_target
      center('矢印が出たら、その方向！', 716, 350, 20, PALE, 116, bold: true)
      cue = target.nil? ? '…' : (target.zero? ? '←' : '→')
      center(cue, 716, 389, 78, target.nil? ? SOFT : PINK, 118, bold: true)
      if target
        rect(533, 483, 366, 7, 0xff_584766, 116)
        rect(533, 483, 366 * (1 - @mini.urgency), 7, PINK, 117)
      end
      center("#{@mini.scores.length} / #{@mini.rounds}   #{@mini.feedback}", 716, 512, 16, LAVENDER, 116)
      button(:left, '← 左 / A', 500, 554, 207, 56, color: PINK)
      button(:right, '右 / D →', 721, 554, 207, 56, color: PINK)
    end

    def draw_camera_game
      center('光ったカメラをキャッチ！', 716, 350, 20, PALE, 116, bold: true)
      6.times do |i|
        x, y = 500 + (i % 3) * 147, 397 + (i / 3) * 88
        lit = @mini.active_target == i
        rect(x, y, 134, 76, lit ? LAVENDER : 0xff_4b3e5c, 116)
        rect(x + 17, y + 19, 28, 23, lit ? PLUM : SOFT, 117)
        rect(x + 22, y + 24, 11, 11, lit ? PALE : PLUM, 118)
        center(lit ? "#{i + 1} 救出!" : "#{i + 1}", x + 86, y + 20, 22, lit ? PLUM : PALE, 118, bold: true)
        rect(x + 10, y + 63, lit ? 114 * (1 - @mini.urgency) : 0, 4, PINK, 119)
        @buttons << { id: %i[one two three four five six][i], x: x, y: y, w: 134, h: 76, enabled: true }
      end
      center("#{@mini.scores.length} / #{@mini.rounds}   #{@mini.feedback}", 716, 583, 16, LAVENDER, 116)
      center('1〜6キー / クリック', 716, 615, 13, SOFT, 116)
    end

    def draw_comments(x, y, width, height, z)
      return unless @comments_enabled
      @comment_images ||= {}
      @feed.active.each do |comment|
        px, py = x + comment[:x], y + comment[:lane] * 29
        color = %i[sleepy danger repel].include?(comment[:event]) ? PINK : 0xff_ffffff
        image = (@comment_images[comment[:text]] ||= Gosu::Image.from_text(comment[:text], 25, font: @font_name, bold: true))
        CroppedImage.draw(image, px + 2, py + 2, 1, z, 0xee_201827, [x, y, width, height])
        CroppedImage.draw(image, px, py, 1, z + 0.1, color, [x, y, width, height])
      end
    end

    def draw_hallucinations(x, y, w, h, z)
      return unless @hallucinations.visible?
      model = @hallucinations
      count = @gentle ? 1 : model.level
      size = w < 400 ? 116 : 184
      opacity = @gentle ? 85 : 105 + model.level * 25
      count.times do |i|
        phase = model.time * 0.8 + i * 2.6
        px = x + w * [0.77, 0.23, 0.52][i] + Math.sin(phase) * (@gentle ? 3 : 20)
        py = y + h * [0.76, 0.53, 0.27][i] + Math.cos(phase * 1.3) * (@gentle ? 2 : 9)
        frame = (model.time * 2 + i).floor % 2
        if model.flee.positive?
          frame = model.flee > 0.55 ? 2 : 3
          px += (0.8 - model.flee) * w * 1.7
        end
        @kuiya.draw(frame / 2, frame % 2, px, py, size, z, (opacity << 24) | 0xddc6ff, clip: [x, y, w, h])
      end
    end
  end
end
