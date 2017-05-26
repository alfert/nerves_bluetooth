defmodule Bluetooth.Test.HCIPort do
  use ExUnit.Case

  alias Bluetooth.HCI
  alias Bluetooth.HCI.Event
  alias Bluetooth.HCI.PortEmulator
  alias Bluetooth.HCI.Event.CommandComplete
  alias Bluetooth.HCI.Commands
  require Logger

  setup do
    {:ok, emulator} = PortEmulator.start_link()
    {:ok, hci} = HCI.start_link(emulator)
    on_exit(:kill_HCI, fn ->
      ref = Process.monitor(hci)
      Process.exit(hci, :kill)
      receive do
        {:DOWN, ^ref, :process, ^hci, _} ->
          Logger.debug("Ok, HCI #{inspect hci} is down")
          :ok
      end
    end)
    {:ok, %{hci: hci, emulator: emulator}}
  end

  test "more detailed command complete event" do
    # Result of read_local_name (ogf: 0x03, ocf: 0x0014)
    # The sequence is zeroes is shortened, to be more handleable
    gen_event = %Event{event: :hci_command_complete_event,
      parameter: <<1, 20, 12, 0, 107, 97, 108, 45, 117, 98, 117, 110, 116, 117, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0>>}

      cc_ev = HCI.Event.decode(gen_event)
      assert %CommandComplete{ogf: 0x03, ocf: 0x14, packets: 1} = cc_ev
      {:ok, name} = Commands.receive_local_name(cc_ev.parameter)
      assert name == "kal-ubuntu"

    # Result of read_local_version_information (ogf: 0x04, ocf: 0x01)
    gen_event = %Event{event: :hci_command_complete_event,
      parameter: <<1, 1, 16, 0, 7, 25, 18, 7, 15, 0, 119, 33>>}
    cc_ev = HCI.Event.decode(gen_event)
    assert %CommandComplete{ogf: 0x04, ocf: 0x01, packets: 1} = cc_ev
    {:ok, version} = Commands.receive_local_version_info(cc_ev.parameter)
    assert version.hci_version_code == 7
    assert String.contains?(version.manufacturer, "Broadcom")
  end

  test "open, command and receive" do
    {:ok, emulator} = PortEmulator.start_link()
    {:ok, hci} = HCI.open([emulator: emulator])
    # this is the Read Local Version Information Command
    assert :ok == HCI.hci_send_command(0x04, 0x01, <<>>)
    event = HCI.hci_receive()
    Logger.debug "Got hci_event: #{inspect event}"
    assert %Event{event: :hci_command_complete_event} = event
    %Event{parameter: params} = event
    assert params == <<1, 1, 16, 0, 7, 25, 18, 7, 15, 0, 119, 33>>
  end

  test  "Send a command and receive an event", %{hci: hci} do
    assert :ok == HCI.hci_init()
    assert true == HCI.hci_is_dev_up()
    assert 0 == HCI.hci_bind_raw(0);
    assert :ok == HCI.hci_set_filter();
    # this is the Read Local Version Information Command
    assert :ok == HCI.hci_send_command(0x04, 0x01, <<>>)
    Process.sleep(500)
    event = HCI.hci_receive()
    Logger.debug "Got hci_event: #{inspect event}"
    assert %Event{event: :hci_command_complete_event} = event
    %Event{parameter: params} = event
    assert params == <<1, 1, 16, 0, 7, 25, 18, 7, 15, 0, 119, 33>>
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
