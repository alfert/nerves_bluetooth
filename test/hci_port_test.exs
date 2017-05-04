defmodule Bluetooth.Test.HCIPort do
  use ExUnit.Case

  alias Bluetooth.HCI

  test "call foo" do
    {:ok, hci} = HCI.start_link()
    x = 5
    y = HCI.foo(x)
    assert y == x + 1
    HCI.stop()
  end

end
