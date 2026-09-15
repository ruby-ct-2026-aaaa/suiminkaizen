# frozen_string_literal: true

require_relative "../spec_helper"

describe SleepGauge do
  it "0 からはじまり、0 は健康な状態である" do
    gauge = SleepGauge.new
    _(gauge.value).must_equal 0.0
    _(gauge.ratio).must_equal 0.0
    _(gauge.fainted?).must_equal false
  end

  it "眠気を足すと増え、実際に増えた量を返す" do
    gauge = SleepGauge.new
    _(gauge.add(120.0)).must_equal 120.0
    _(gauge.value).must_equal 120.0
  end

  it "0 より下には下がらない" do
    gauge = SleepGauge.new(20.0)
    _(gauge.reduce(50.0)).must_equal 20.0
    _(gauge.value).must_equal 0.0
  end

  it "1000 を超えず、超えたぶんは切り捨てられる" do
    gauge = SleepGauge.new(980.0)
    _(gauge.add(100.0)).must_equal 20.0
    _(gauge.value).must_equal Config::MAX_GAUGE
  end

  it "1000 に達したら気絶している" do
    gauge = SleepGauge.new(999.0)
    _(gauge.fainted?).must_equal false
    gauge.add(1.0)
    _(gauge.fainted?).must_equal true
  end

  it "負の値を渡しても何も起きない" do
    gauge = SleepGauge.new(100.0)
    _(gauge.add(-50.0)).must_equal 0.0
    _(gauge.reduce(-50.0)).must_equal 0.0
    _(gauge.value).must_equal 100.0
  end

  it "いちばん高かったところを覚えている" do
    gauge = SleepGauge.new
    gauge.add(400.0)
    gauge.reduce(300.0)
    _(gauge.peak).must_equal 400.0
  end
end
