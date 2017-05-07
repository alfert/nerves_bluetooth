defmodule Bluetooth.Test.HCIPort do
  use ExUnit.Case

  alias Bluetooth.HCI
  require Logger

  setup do
    {:ok, hci} = HCI.start_link()
    on_exit(:kill_HCI, fn -> 
      ref = Process.monitor(hci)
      Process.exit(hci, :kill)
      receive do
        {:DOWN, ^ref, :process, ^hci, _} -> 
          Logger.debug("Ok, HCI #{inspect hci} is down")
          :ok
      end
    end)
    {:ok, %{hci: hci}}
  end

  test "which controller is up", %{hci: hci} do
    assert :ok == HCI.hci_init()
    assert true == HCI.hci_is_dev_up()
    assert 0 == HCI.hci_dev_id_for(true)
    assert nil == HCI.hci_dev_id_for(false)
  end
  

  test "get some information about controller", %{hci: hci} do
    assert hci == GenServer.whereis(HCI)
    assert :ok = HCI.hci_init()
    assert true = HCI.hci_is_dev_up()
  end
  
  test "call hci_init", %{hci: hci}  do
    assert :ok = HCI.hci_init()
    # HCI.stop()
  end 

  test "call foo", %{hci: hci} do
    assert hci == GenServer.whereis(HCI)
    x = 5
    y = HCI.foo(x)
    assert y == x + 1
    # HCI.stop()
  end

  

end
