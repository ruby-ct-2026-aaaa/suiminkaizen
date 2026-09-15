# frozen_string_literal: true

module Suiminkaizen
  # ドット絵の定義集。
  # 小文字＝固定色、大文字の A / B / W ＝呼び出し側で差し替える可変色。
  module Sprites
    BASE = {
      "k" => Palette::INK,
      "x" => Palette::INK,
      "h" => Palette::HAIR,
      "H" => Palette::HAIR_HI,
      "s" => Palette::SKIN,
      "S" => Palette::SKIN_DARK,
      "w" => Palette::WHITE,
      "p" => Palette::INK,
      "r" => Palette::CRIMSON,
      "c" => Palette::CYAN,
      "C" => Palette.shade(Palette::CYAN, 0.65),
      "b" => Palette::DEEP_BLUE,
      "m" => Palette::STEEL,
      "y" => Palette::YELLOW,
      "o" => Palette::ORANGE,
      "u" => Palette::AQUA,
      "n" => Palette::BROWN,
      "W" => Palette::WHITE,
      "A" => Palette::WHITE,
      "B" => Palette::GRAY
    }.freeze

    # 峰小輔・直立（16x24）。
    # 寝癖で跳ねた髪と、目の下のクマ(r)がショートスリーパーの証。
    KOSUKE = PixelSprite.new([
      "...hhh...hhh....",
      "..hhhhhhhhhhhh..",
      ".hhhhhhhhhhhhhh.",
      ".hhhhhhhhhhhhhh.",
      ".hhhsssssssshhh.",
      ".hhsssssssssshh.",
      ".hsswpsssspwssh.",
      ".hssrrssssrrssh.",
      ".hssssskksssssh.",
      "..hssssssssssh..",
      "......ssss......",
      "...cccccccccc...",
      ".ssccccccccccss.",
      ".ssccccccccccss.",
      ".sscccccccccass.",
      ".ssccCCCCCCccss.",
      "..scccCCCCcccs..",
      "...cccccccccc...",
      "...bbbbbbbbbb...",
      "...bbbbbbbbbb...",
      "...bbb....bbb...",
      "...sss....sss...",
      "...sss....sss...",
      "..kkkkk..kkkkk.."
    ], BASE.merge("a" => Palette::CYAN))

    # 湯船につかった峰小輔（16x12）。
    # 目を閉じて、危険なほどリラックスしている。
    KOSUKE_BATH = PixelSprite.new([
      "...hhh...hhh....",
      "..hhhhhhhhhhhh..",
      ".hhhhhhhhhhhhhh.",
      ".hhhsssssssshhh.",
      ".hhsssssssssshh.",
      ".hskkksssklkksh.",
      ".hsrrrsssrrrssh.",
      ".hssssseossssh..",
      "..hssssssssssh..",
      "......ssss......",
      "...ssssssssss...",
      "..ssssssssssss.."
    ], BASE.merge("l" => Palette::INK, "e" => Palette::ORANGE))

    # 30分だけ眠る峰小輔（24x12）。
    KOSUKE_SLEEP = PixelSprite.new([
      "........................",
      ".....hhhhhhh............",
      "....hhhhhhhhh...........",
      "....hhsssssssh..........",
      "....hsskkssssh..........",
      "....hssssssssh..........",
      "....hhsssssshcccccccc...",
      "..WWWWWWWWWWWcccccccc...",
      "..WWWWWWWWWWWcccccccc...",
      "..CCCCCCCCCCCCCCCCCC....",
      "..kkkkkkkkkkkkkkkkkk....",
      "........................"
    ], BASE)

    # 気絶して床に伸びた峰小輔（24x14）。目がぐるぐる(x)になっている。
    KOSUKE_FAINT = PixelSprite.new([
      "........................",
      "....hhhh................",
      "...hhhhhh...............",
      "...hhssssh..............",
      "...hsxsxsh..............",
      "...hssssssh.............",
      "...hhsooosh.............",
      "..ss.hcccccccccc........",
      "...sccccccccccccss......",
      "..bbbbbbbbbbbbbbbb......",
      "..ssssssssssssssss......",
      "..kkkk........kkkkk.....",
      "........................",
      "........................"
    ], BASE)

    # 錠剤（8x8）。A/B を差し替えてサプリの種類を描き分ける。
    TABLET = PixelSprite.new([
      "..AAAA..",
      ".AAAAAA.",
      "AAWAAAAA",
      "AAWAAAAB",
      "AAAAAAAB",
      "AAAAAABB",
      ".AAAABB.",
      "..ABBB.."
    ], BASE)

    # カプセル（8x8）。左右で色が違うのが錠剤との見分けどころ。
    CAPSULE = PixelSprite.new([
      "..AABB..",
      ".AAAABB.",
      "AAWAABBB",
      "AAWAABBB",
      "AAAABBBB",
      "AAAABBBB",
      ".AAABBB.",
      "..AABB.."
    ], BASE)

    # 水のコップ（10x11）
    GLASS = PixelSprite.new([
      "mmmmmmmmmm",
      "m........m",
      "m.uuuuuu.m",
      "m.uuuuuu.m",
      "m.uuuuuu.m",
      "m.uuuuuu.m",
      "m.uuuuuu.m",
      ".m.uuuu.m.",
      ".m.uuuu.m.",
      ".mmuuuumm.",
      "..mmmmmm.."
    ], BASE)

    # アヒル（10x8）。お風呂の相棒。
    DUCK = PixelSprite.new([
      "...yyy....",
      "..yyyyy...",
      "..ykyyyo..",
      "..yyyyyo..",
      ".yyyyyy...",
      "yyyyyyyy..",
      "yyyyyyyyy.",
      ".oooooooo."
    ], BASE)

    # ダンベル（12x6）。ジムの背景用。
    DUMBBELL = PixelSprite.new([
      "kk........kk",
      "kk........kk",
      "kkkmmmmmmkkk",
      "kkkmmmmmmkkk",
      "kk........kk",
      "kk........kk"
    ], BASE)

    # 湯気（6x6）。A を半透明の白にして重ねる。
    STEAM = PixelSprite.new([
      "..AA..",
      ".AAAA.",
      "AAAAAA",
      "AAAAAA",
      ".AAAA.",
      "..AA.."
    ], BASE)

    ALL = {
      kosuke: KOSUKE, kosuke_bath: KOSUKE_BATH, kosuke_sleep: KOSUKE_SLEEP,
      kosuke_faint: KOSUKE_FAINT, tablet: TABLET, capsule: CAPSULE,
      glass: GLASS, duck: DUCK, dumbbell: DUMBBELL, steam: STEAM
    }.freeze
  end
end
