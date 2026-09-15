# frozen_string_literal: true

module Suiminkaizen
  # 画面上部の睡眠ゲージと、眠気そのものを見せる画面効果。
  #
  # 数字を読まなくても「やばい」と分かることを重視していて、
  # ゲージが溜まるほど画面の四隅が暗く落ち、まぶたが落ちる回数が増える。
  module Hud
    BAR_X = 6
    BAR_Y = 15
    BAR_W = Config::W - 12
    BAR_H = 9

    Z_HUD     = 200
    Z_OVERLAY = 250

    module_function

    def draw(state, time = 0.0)
      draw_bar(state, time)
      draw_labels(state)
    end

    def draw_bar(state, time)
      ratio = state.gauge.ratio
      color = Palette.gauge_color(ratio)

      # 危険域では脈打たせる
      if ratio > 0.8
        pulse = (Math.sin(time * 9.0) + 1.0) * 0.5
        color = Palette.mix(color, Palette::WHITE, pulse * 0.45)
      end

      Px.rect(BAR_X - 1, BAR_Y - 1, BAR_W + 2, BAR_H + 2, Palette::INK, Z_HUD)
      Px.rect(BAR_X, BAR_Y, BAR_W, BAR_H, Palette.rgb(0x241f42), Z_HUD + 1)

      filled = (BAR_W * ratio).round
      if filled.positive?
        Px.rect(BAR_X, BAR_Y, filled, BAR_H, color, Z_HUD + 2)
        Px.rect(BAR_X, BAR_Y, filled, 2, Palette.mix(color, Palette::WHITE, 0.45), Z_HUD + 3)
      end

      # 100きざみの目盛り
      (1..9).each do |i|
        x = BAR_X + (BAR_W * i / 10.0).round
        Px.rect(x, BAR_Y, 1, BAR_H, Palette.alpha(Palette::INK, 110), Z_HUD + 4)
      end
      Px.frame(BAR_X, BAR_Y, BAR_W, BAR_H, Palette.alpha(Palette::WHITE, 60), Z_HUD + 5)
    end

    def draw_labels(state)
      font = Assets.tiny
      Px.text_shadow(font, "DAY #{state.day} / #{Config::TOTAL_DAYS}",
                     BAR_X, 3, Palette::WHITE, Z_HUD + 6)

      gauge = state.gauge
      label = "睡眠ゲージ #{gauge.to_i} / #{Config::MAX_GAUGE.to_i}"
      tone = gauge.ratio > 0.8 ? Palette::RED : Palette::BONE
      Px.text_shadow(font, label, Config::W - BAR_X, 3, tone, Z_HUD + 6, align: :right)
    end

    # --- 眠気の画面効果 ---------------------------------------------------

    def draw_drowsiness(state)
      ratio = state.gauge.ratio
      vignette(ratio)
      eyelids(state)
      limit_warning(state) if ratio >= 0.9
    end

    # 四隅を暗く落として視野を狭める。
    def vignette(ratio)
      return if ratio < 0.12

      strength = ((ratio - 0.12) / 0.88 * 235).round
      dark  = Palette.alpha(Palette::INK, strength)
      clear = Palette.alpha(Palette::INK, 0)
      w = Config::W
      h = Config::H
      depth = 34 + (ratio * 62).round

      Px.quad(0, 0, w, 0, 0, depth, w, depth, dark, dark, clear, clear, Z_OVERLAY)
      Px.quad(0, h - depth, w, h - depth, 0, h, w, h, clear, clear, dark, dark, Z_OVERLAY)
      Px.quad(0, 0, depth, 0, 0, h, depth, h, dark, clear, dark, clear, Z_OVERLAY)
      Px.quad(w - depth, 0, w, 0, w - depth, h, w, h, clear, dark, clear, dark, Z_OVERLAY)
    end

    # まぶた。上下から黒帯が降りてくる。
    def eyelids(state)
      closure = state.eyelid_closure
      return if closure <= 0.01

      h = (Config::H / 2.0 * closure).round
      return if h <= 0

      Px.rect(0, 0, Config::W, h, Palette::INK, Z_OVERLAY + 1)
      Px.rect(0, Config::H - h, Config::W, h, Palette::INK, Z_OVERLAY + 1)
      Px.rect(0, h, Config::W, 1, Palette.rgb(0x3a2f4d), Z_OVERLAY + 2)
      Px.rect(0, Config::H - h - 1, Config::W, 1, Palette.rgb(0x3a2f4d), Z_OVERLAY + 2)
    end

    def limit_warning(state)
      pulse = (Math.sin(state.clock * 11.0) + 1.0) * 0.5
      edge = Palette.alpha(Palette::RED, (60 + pulse * 90).round)
      Px.frame(0, 0, Config::W, Config::H, edge, Z_OVERLAY + 3, 3)
      Px.text_shadow(Assets.small, "限 界 で す", Config::W / 2, Config::H - 30,
                     Palette.alpha(Palette::RED, (150 + pulse * 105).round),
                     Z_OVERLAY + 4, align: :center)
    end

    # 汎用の暗幕（シーン切り替えのフェード用）。
    def curtain(alpha, z = Z_OVERLAY + 8)
      return if alpha <= 0

      Px.rect(0, 0, Config::W, Config::H, Palette.alpha(Palette::INK, alpha), z)
    end
  end
end
