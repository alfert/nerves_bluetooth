defmodule Rpi0BtTest do
  use ExUnit.Case
  doctest Bluetooth

  test "Strip Ansi Sequences" do
    s = "\r\e[0;94m[bluetooth]\e[0m# "
    clean = Bluetooth.Ctl.strip_ansi_sequences(s)
    assert clean == "[bluetooth]# "
  end
end
