# frozen_string_literal: true

require_relative "../spec_helper"

describe PixelSprite do
  it "行の長さが揃っていなければ読み込み時に落ちる" do
    _(proc { PixelSprite.new(%w[AAA AA], "A" => Palette::WHITE) })
      .must_raise ArgumentError
  end

  it "横に続く同じ色をひとつの区間へまとめる" do
    sprite = PixelSprite.new(["AAA.BB"], "A" => Palette::WHITE, "B" => Palette::RED)
    spans = sprite.instance_variable_get(:@spans)
    _(spans.size).must_equal 2
    _(spans[0]).must_equal [0, 0, 3, "A"]
    _(spans[1]).must_equal [0, 4, 6, "B"]
  end

  it "透明（. と空白）は区間にならない" do
    sprite = PixelSprite.new([". . ."], "A" => Palette::WHITE)
    _(sprite.instance_variable_get(:@spans)).must_be_empty
  end

  it "大きさを読み取れる" do
    _(Sprites::KOSUKE.width).must_equal 16
    _(Sprites::KOSUKE.height).must_equal 24
  end

  it "定義したドット絵はすべて読み込める" do
    Sprites::ALL.each do |name, sprite|
      _(sprite.width).must_be :>, 0, "#{name} の幅が 0"
      _(sprite.height).must_be :>, 0, "#{name} の高さが 0"
    end
  end
end

describe Camera do
  before { @camera = Camera.new }

  it "画面の中心が消失点になる" do
    x, y, = @camera.project(0.0, 0.0, 5.0)
    _(x).must_be_close_to Config::W / 2.0
    _(y).must_be_close_to Config::H * 0.44
  end

  it "遠いものほど小さく写る" do
    near = @camera.scale_at(2.0)
    far  = @camera.scale_at(8.0)
    _(near).must_be :>, far
    _(near / far).must_be_close_to 4.0
  end

  it "同じ幅のものは距離に反比例して縮む" do
    near_left, = @camera.project(-1.0, 0.0, 2.0)
    near_right, = @camera.project(1.0, 0.0, 2.0)
    far_left, = @camera.project(-1.0, 0.0, 4.0)
    far_right, = @camera.project(1.0, 0.0, 4.0)
    _((near_right - near_left) / (far_right - far_left)).must_be_close_to 2.0
  end

  it "カメラの手前に回り込んでも破綻しない" do
    x, y, scale = @camera.project(1.0, 1.0, -5.0)
    _(x.finite?).must_equal true
    _(y.finite?).must_equal true
    _(scale).must_be :>, 0
  end

  it "揺れは時間とともに収まる" do
    @camera.kick(1.0)
    _(@camera.shaking?).must_equal true
    20.times { @camera.update(0.05) }
    _(@camera.shaking?).must_equal false
  end
end

describe Stage do
  it "部屋はカメラの前に組み立てられている" do
    _(Stage::NEAR_Z).must_be :<, Stage::FAR_Z
    _(Stage::CEIL_Y).must_be :<, Stage::FLOOR_Y
    _(Stage::HALF_W).must_be :>, 0
  end

  it "手前ほど描画順が後ろになる（奥のものが先に描かれる）" do
    _(Config.depth_z(2.0)).must_be :>, Config.depth_z(8.0)
  end
end
