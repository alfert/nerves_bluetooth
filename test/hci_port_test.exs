defmodule Bluetooth.Test.HCIPort do
  use ExUnit.Case

  alias Bluetooth.HCI

  test "call foo" do
    {:ok, hci} = HCI.start_link()
    assert hci == GenServer.whereis(HCI)
    x = 5
    y = HCI.foo(x)
    assert y == x + 1
    HCI.stop()
  end

  test "call hci_init" do
    {:ok, hci} = HCI.start_link()
    assert :ok = HCI.hci_init()
    HCI.stop()
  end 

end
