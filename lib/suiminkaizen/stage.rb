# frozen_string_literal: true

module Suiminkaizen
  # 疑似3Dの部屋。床・天井・左右の壁・奥の壁を1点透視で描く。
  #
  # ドット絵の平面を並べているだけだが、
  #   1. 奥行き方向に等間隔のグリッドを敷く
  #   2. 頂点カラーで奥ほど背景色へ沈ませる（空気遠近）
  # の2点だけで立体に見える。スプライトは PixelSprite#draw3d で同じ投影に乗せる。
  module Stage
    HALF_W  =  3.2   # 部屋の半幅
    FLOOR_Y =  1.7   # 目線から床まで
    CEIL_Y  = -1.3   # 目線から天井まで
    NEAR_Z  =  1.1   # 手前のクリップ面
    FAR_Z   = 11.0   # 奥の壁

    def self.c(hex)
      Palette.rgb(hex)
    end

    # 照明をしっかり入れた明るい部屋。
    # 眠気が溜まるほど Hud の暗幕で視界が落ちていくので、
    # 素の部屋のほうは明るくしておかないと終盤が何も見えなくなる。
    THEMES = {
      # トレーニングルーム
      gym: {
        fog:   c(0x4a4280),
        floor: c(0x7c6fae), floor_line: c(0xa89ad8),
        wall:  c(0x625899), ceil: c(0x554b8a)
      },
      # 湯気のこもった浴室
      bath: {
        fog:   c(0x5e9db8),
        floor: c(0xc6e4e9), floor_line: c(0x8fbecb),
        wall:  c(0xdcf1f4), ceil: c(0xa9d2dd)
      },
      # キッチン
      kitchen: {
        fog:   c(0x6d5473),
        floor: c(0xbc8054), floor_line: c(0x94603a),
        wall:  c(0xb09578), ceil: c(0x86705c)
      },
      # 寝室（タイトル・睡眠・リザルト用）
      bedroom: {
        fog:   c(0x3a3270),
        floor: c(0x5d5390), floor_line: c(0x8b7dc4),
        wall:  c(0x4c4283), ceil: c(0x403873)
      },
      # ヘッドマッサージのサロン
      salon: {
        fog:   c(0x8a7490),
        floor: c(0xd8c6b2), floor_line: c(0xb09a86),
        wall:  c(0xeaddcd), ceil: c(0xc4b09c)
      }
    }.freeze

    STARS = [
      [-2.05, -0.78], [-1.72, -0.55], [-1.44, -0.83], [-1.18, -0.42],
      [-0.92, -0.70], [-2.28, -0.36], [-1.60, -0.25], [-0.78, -0.86]
    ].freeze

    class << self
      def fog(theme)
        THEMES.fetch(theme)[:fog]
      end

      def draw(camera, theme, time = 0.0)
        t = THEMES.fetch(theme)
        Px.rect(0, 0, Config::W, Config::H, t[:fog], 0)

        surface(camera, CEIL_Y, t[:ceil], t[:fog], 1)
        surface(camera, FLOOR_Y, t[:floor], t[:fog], 1)
        floor_grid(camera, t)
        side_wall(camera, -HALF_W, t, 3)
        side_wall(camera,  HALF_W, t, 3)
        back_wall(camera, t, 3)

        case theme
        when :gym     then decorate_gym(camera, t, time)
        when :bath    then decorate_bath(camera, t, time)
        when :kitchen then decorate_kitchen(camera, t, time)
        when :bedroom then decorate_bedroom(camera, t, time)
        when :salon   then decorate_salon(camera, t, time)
        end
      end

      # --- 基本の面 -------------------------------------------------------

      # 床や天井のような水平面を、手前から奥へのグラデーションつきで敷く。
      def surface(camera, y, near_color, far_color, z)
        w = HALF_W * 1.06
        fl = camera.project(-w, y, FAR_Z)
        fr = camera.project( w, y, FAR_Z)
        nl = camera.project(-w, y, NEAR_Z * 0.55)
        nr = camera.project( w, y, NEAR_Z * 0.55)
        Px.quad(fl[0], fl[1], fr[0], fr[1], nl[0], nl[1], nr[0], nr[1],
                far_color, far_color, near_color, near_color, z)
      end

      # 床のグリッド。奥へ行くほど間隔を広げると線が潰れて汚くならない。
      def floor_grid(camera, t)
        line = t[:floor_line]
        far  = t[:fog]

        depth = NEAR_Z
        step  = 0.5
        while depth < FAR_Z
          shade = Palette.mix(line, far, (depth - NEAR_Z) / (FAR_Z - NEAR_Z))
          band(camera, FLOOR_Y, depth, depth + 0.06, shade, 2)
          depth += step
          step *= 1.2
        end

        x = -HALF_W
        while x <= HALF_W + 0.01
          stripe(camera, FLOOR_Y, x, x + 0.045, line, far, 2)
          x += 0.8
        end
      end

      # 一定の奥行きに引く横線。手前ほど太く見える。
      def band(camera, y, z_near, z_far, color, z)
        fl = camera.project(-HALF_W, y, z_far)
        fr = camera.project( HALF_W, y, z_far)
        nl = camera.project(-HALF_W, y, z_near)
        nr = camera.project( HALF_W, y, z_near)
        Px.quad(fl[0], fl[1], fr[0], fr[1], nl[0], nl[1], nr[0], nr[1],
                color, color, color, color, z)
      end

      # 消失点へ向かって伸びる縦線。奥行きの範囲は指定できる。
      def stripe(camera, y, x0, x1, near_color, far_color, z,
                 z_near = NEAR_Z, z_far = FAR_Z)
        fl = camera.project(x0, y, z_far)
        fr = camera.project(x1, y, z_far)
        nl = camera.project(x0, y, z_near)
        nr = camera.project(x1, y, z_near)
        Px.quad(fl[0], fl[1], fr[0], fr[1], nl[0], nl[1], nr[0], nr[1],
                far_color, far_color, near_color, near_color, z)
      end

      # 床の一部だけを塗る矩形（判定ゾーンの表示などに使う）。
      def patch(camera, x0, x1, z_near, z_far, y, near_color, far_color, z)
        fl = camera.project(x0, y, z_far)
        fr = camera.project(x1, y, z_far)
        nl = camera.project(x0, y, z_near)
        nr = camera.project(x1, y, z_near)
        Px.quad(fl[0], fl[1], fr[0], fr[1], nl[0], nl[1], nr[0], nr[1],
                far_color, far_color, near_color, near_color, z)
      end

      def side_wall(camera, x, t, z)
        nt = camera.project(x, CEIL_Y,  NEAR_Z)
        ft = camera.project(x, CEIL_Y,  FAR_Z)
        nb = camera.project(x, FLOOR_Y, NEAR_Z)
        fb = camera.project(x, FLOOR_Y, FAR_Z)
        Px.quad(nt[0], nt[1], ft[0], ft[1], nb[0], nb[1], fb[0], fb[1],
                t[:wall], t[:fog], t[:wall], t[:fog], z)
      end

      def back_wall(camera, t, z)
        far = Palette.mix(t[:wall], t[:fog], 0.55)
        tl = camera.project(-HALF_W, CEIL_Y,  FAR_Z)
        tr = camera.project( HALF_W, CEIL_Y,  FAR_Z)
        bl = camera.project(-HALF_W, FLOOR_Y, FAR_Z)
        br = camera.project( HALF_W, FLOOR_Y, FAR_Z)
        Px.quad(tl[0], tl[1], tr[0], tr[1], bl[0], bl[1], br[0], br[1],
                far, far, far, far, z)
      end

      # 奥の壁に矩形を貼る。
      def wall_rect(camera, x0, y0, x1, y1, color, z, depth = FAR_Z)
        a = camera.project(x0, y0, depth)
        b = camera.project(x1, y1, depth)
        Px.rect(a[0], a[1], b[0] - a[0], b[1] - a[1], color, z)
      end

      # 左右の壁に、奥行き方向へ伸びる板を貼る。
      def side_rect(camera, x, y0, y1, z0, z1, color, z)
        a = camera.project(x, y0, z0)
        b = camera.project(x, y0, z1)
        c = camera.project(x, y1, z0)
        d = camera.project(x, y1, z1)
        Px.quad(a[0], a[1], b[0], b[1], c[0], c[1], d[0], d[1],
                color, color, color, color, z)
      end

      # --- 部屋ごとの飾り付け --------------------------------------------

      def decorate_gym(camera, t, time)
        # 夜景の窓
        wall_rect(camera, -2.3, -0.95, -0.7, 0.15, Palette::INK, 4)
        wall_rect(camera, -2.22, -0.89, -0.78, 0.09, c(0x14224d), 5)
        STARS.each do |(sx, sy)|
          wall_rect(camera, sx, sy, sx + 0.05, sy + 0.05, Palette::WHITE, 6)
        end
        wall_rect(camera, -1.05, -0.80, -0.83, -0.58, Palette::BONE, 6)
        [[-2.15, -0.18, -1.85], [-1.80, -0.05, -1.55],
         [-1.45, -0.26, -1.10], [-1.00, -0.02, -0.82]].each do |(x0, top, x1)|
          wall_rect(camera, x0, top, x1, 0.15, c(0x0f1836), 6)
        end

        # 鏡張りの壁
        wall_rect(camera, 0.6, -0.95, 2.4, 0.5, c(0x3c3a68), 4)
        wall_rect(camera, 0.68, -0.88, 2.32, 0.43, c(0x4f4d80), 5)
        wall_rect(camera, 0.68, -0.88, 1.10, 0.43, c(0x625f96), 6)

        # 壁際のダンベル
        [[-2.6, 7.4], [-2.6, 8.4], [2.6, 7.9], [2.6, 8.9]].each do |(x, z)|
          Sprites::DUMBBELL.draw3d(camera, x, FLOOR_Y, z, 0.22, fog: t[:fog])
        end

        # 天井の蛍光灯。わずかに明滅させて深夜感を出す。
        flick = Math.sin(time * 9.3) > -0.93 ? Palette::WHITE : Palette::SLATE
        y = CEIL_Y + 0.03
        [3.6, 6.2, 9.0].each do |z|
          nl = camera.project(-0.65, y, z)
          nr = camera.project( 0.65, y, z)
          fl = camera.project(-0.65, y, z + 0.5)
          fr = camera.project( 0.65, y, z + 0.5)
          Px.quad(fl[0], fl[1], fr[0], fr[1], nl[0], nl[1], nr[0], nr[1],
                  Palette.mix(flick, t[:fog], 0.35), Palette.mix(flick, t[:fog], 0.35),
                  flick, flick, 4)
        end
      end

      def decorate_bath(camera, t, _time)
        tile = c(0x7fa8b3)
        y = CEIL_Y
        while y < FLOOR_Y
          wall_rect(camera, -HALF_W, y, HALF_W, y + 0.03, tile, 4)
          y += 0.42
        end
        x = -HALF_W
        while x <= HALF_W
          wall_rect(camera, x, CEIL_Y, x + 0.03, FLOOR_Y, tile, 4)
          x += 0.42
        end

        # 曇りガラスの小窓
        wall_rect(camera, 1.1, -0.9, 2.3, -0.1, c(0x5c8390), 5)
        wall_rect(camera, 1.16, -0.84, 2.24, -0.16, c(0xc3e0e6), 6)
        wall_rect(camera, 1.16, -0.55, 2.24, -0.52, c(0x5c8390), 7)

        # シャンプーの棚
        side_rect(camera, -HALF_W + 0.02, -0.3, -0.24, 5.0, 6.6, c(0x6f97a3), 5)
        Sprites::GLASS.draw3d(camera, -2.9, -0.3, 5.5, 0.34,
                              palette: { "u" => Palette::PINK }, fog: t[:fog])
        Sprites::GLASS.draw3d(camera, -2.9, -0.3, 6.2, 0.34,
                              palette: { "u" => Palette::GREEN }, fog: t[:fog])
      end

      def decorate_kitchen(camera, t, time)
        # 吊り戸棚
        wall_rect(camera, -2.9, -1.1, 2.9, -0.15, c(0x8a6b4a), 4)
        x = -2.9
        while x < 2.9
          wall_rect(camera, x, -1.1, x + 0.04, -0.15, c(0x5a4028), 5)
          x += 0.72
        end
        wall_rect(camera, -2.9, -0.19, 2.9, -0.15, c(0x5a4028), 5)

        # 棚に並んだサプリのボトル
        [[-2.4, Palette::ORANGE], [-1.7, Palette::GREEN], [-1.0, Palette::RED],
         [1.0, Palette::CYAN], [1.7, Palette::YELLOW], [2.4, Palette::PINK]].each do |(bx, col)|
          wall_rect(camera, bx - 0.16, -0.62, bx + 0.16, -0.20, col, 6)
          wall_rect(camera, bx - 0.10, -0.70, bx + 0.10, -0.62, Palette::BONE, 6)
        end

        # 流し台
        wall_rect(camera, -2.9, 0.55, 2.9, 0.75, c(0x9aa6b4), 4)
        wall_rect(camera, -2.9, 0.75, 2.9, FLOOR_Y, c(0x4c3a2a), 4)

        # 冷蔵庫の灯り
        glow = Palette.alpha(Palette::YELLOW, 40 + (Math.sin(time * 1.7) * 12).round)
        wall_rect(camera, 2.2, -0.1, 2.9, 1.4, glow, 5)
      end

      # ヘッドマッサージのサロン。間接照明と観葉植物で、いかにも眠くなる部屋。
      def decorate_salon(camera, t, time)
        # 木目の腰壁
        wall_rect(camera, -HALF_W, 0.35, HALF_W, FLOOR_Y, c(0xa8815c), 4)
        wall_rect(camera, -HALF_W, 0.35, HALF_W, 0.42, c(0x7d5c3e), 5)

        # 大きな鏡
        wall_rect(camera, -1.9, -0.95, 1.9, 0.2, c(0xb49f8c), 4)
        wall_rect(camera, -1.8, -0.88, 1.8, 0.13, c(0xd7ecef), 5)
        wall_rect(camera, -1.8, -0.88, -0.9, 0.13, c(0xe8f7f9), 6)

        # 間接照明。ゆっくり明滅させて、まぶたが重くなる感じを出す。
        glow = (Math.sin(time * 0.9) + 1.0) * 0.5
        warm = Palette.mix(c(0xffd9a0), c(0xffb567), glow)
        [-2.6, 2.6].each do |x|
          wall_rect(camera, x - 0.28, -0.85, x + 0.28, -0.25, warm, 5)
        end
        [3.0, 6.0, 9.0].each do |z|
          a = camera.project(-0.55, CEIL_Y + 0.04, z)
          b = camera.project(0.55, CEIL_Y + 0.04, z + 0.45)
          Px.rect(a[0], a[1], b[0] - a[0], (b[1] - a[1]).abs + 1,
                  Palette.alpha(warm, 210), 4)
        end

        # 観葉植物とタオル棚
        [[-2.85, 5.0], [2.85, 6.2]].each do |(x, z)|
          pot = camera.project(x, FLOOR_Y, z)
          scale = camera.scale_at(z)
          Px.rect(pot[0] - 0.22 * scale, pot[1] - 0.3 * scale,
                  0.44 * scale, 0.3 * scale, c(0x9c6b4a), Config.depth_z(z))
          Px.rect(pot[0] - 0.3 * scale, pot[1] - 0.95 * scale,
                  0.6 * scale, 0.66 * scale, c(0x4f8a4a), Config.depth_z(z) + 1)
        end
        side_rect(camera, -HALF_W + 0.02, -0.25, -0.08, 6.5, 8.2, c(0xf2ece2), 5)
      end

      def decorate_bedroom(camera, _t, time)
        # 窓の外はまだ夜明け前
        wall_rect(camera, -2.5, -1.0, -0.4, 0.4, Palette::INK, 4)
        wall_rect(camera, -2.42, -0.93, -0.48, 0.33, c(0x1b2a5e), 5)
        STARS.each do |(sx, sy)|
          next unless Math.sin(time * 2.2 + sx * 7.0).positive?

          wall_rect(camera, sx - 0.2, sy, sx - 0.15, sy + 0.05, Palette::WHITE, 6)
        end
        wall_rect(camera, -1.45, -0.62, -1.15, -0.32, Palette::BONE, 6)

        # 棚
        side_rect(camera, HALF_W - 0.02, 0.45, 0.52, 4.0, 5.6, c(0x3a316a), 5)

        # ベッド。天面と手前の側面を透視で組んで箱に見せる。
        bed_top = FLOOR_Y - 0.5
        top_far   = camera.project(-2.95, bed_top, 6.4)
        top_far_r = camera.project(-0.35, bed_top, 6.4)
        top_near  = camera.project(-2.95, bed_top, 3.0)
        top_near_r = camera.project(-0.35, bed_top, 3.0)
        Px.quad(top_far[0], top_far[1], top_far_r[0], top_far_r[1],
                top_near[0], top_near[1], top_near_r[0], top_near_r[1],
                c(0x3f3775), c(0x3f3775), c(0x544a92), c(0x544a92), 8)

        side_l = camera.project(-2.95, FLOOR_Y, 3.0)
        side_r = camera.project(-0.35, FLOOR_Y, 3.0)
        Px.quad(top_near[0], top_near[1], top_near_r[0], top_near_r[1],
                side_l[0], side_l[1], side_r[0], side_r[1],
                c(0x2c2555), c(0x2c2555), c(0x221c44), c(0x221c44), 9)

        # 枕
        pillow_far = camera.project(-2.8, bed_top - 0.03, 6.2)
        pillow_near = camera.project(-1.9, bed_top - 0.03, 5.4)
        Px.rect(pillow_far[0], pillow_far[1],
                pillow_near[0] - pillow_far[0], pillow_near[1] - pillow_far[1],
                c(0xb9b3cf), 10)
      end
    end
  end
end
