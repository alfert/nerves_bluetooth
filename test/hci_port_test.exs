defmodule Bluetooth.Test.HCIPort do
  use ExUnit.Case

  alias Bluetooth.HCI
  alias Bluetooth.HCI.Event
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

  test "interprete command complete event" do
    # result of Read Local Version Information Command
    event_bin = <<4, 14, 12, 1, 1, 16, 0, 7, 25, 18, 7, 15, 0, 119, 33>>
    event = HCI.interprete_event(event_bin)
    assert %Event{event: :hci_command_complete_event, parameter: params} = event
    assert params = <<1, 1, 16, 0, 7, 25, 18, 7, 15, 0, 119, 33>>
  end

  test  "Send a command", %{hci: hci} do
    assert :ok == HCI.hci_init()
    assert true == HCI.hci_is_dev_up()
    assert 0 == HCI.hci_bind_raw(0);
    # assert 0 == HCI.set_filter();
    # this is the Read Local Version Information Command
    assert :ok == HCI.hci_send_command(0x04, 0x01, <<>>)
    Process.sleep(500)
  end

  test "command package generation" do
    ogf = 4
    ocf = 1
    # opcode:  01234567 89ABCDEF
    # ocf      10000000 00
    # ogf                 001000
    # bytes:   0x01     0x04
    assert 0o377 == 0xff
    assert 0o20 == 0x10
    assert <<0x01, 0x01, 0o20, 0x00>> == HCI.create_command(ogf, ocf, <<>>)
  end

  test "Bind the socket", %{hci: hci} do
    assert :ok == HCI.hci_init()
    assert true == HCI.hci_is_dev_up()
    # bind hci_device to the socket 0
    assert 0 == HCI.hci_bind_raw(0);
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
