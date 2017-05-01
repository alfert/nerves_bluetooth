defmodule Bluetooth.Test.Ctl do

  use ExUnit.Case
  @moduletag capture_log: false

  alias Bluetooth.Ctl
  alias Bluetooth.GenBle

  setup do
    {:ok, controller} = Bluetooth.Ctl.start(fn -> IO.puts "Hey Hey Hey" end)
    on_exit(fn ->
      ref = Process.monitor(controller)
      Process.exit(controller, :kill)
      receive do
        {:DOWN, ^ref, :process, ^controller, _} -> :ok
      end
    end)
    {:ok, %{controller: controller}}
  end

  def script_as_list(filename) do
    filename
    |> File.read!()
    |> String.splitter("\n")
    |> Enum.map(&Bluetooth.Ctl.strip_ansi_sequences/1)
  end

  def parse_and_filter_commands(events) do
    events
    |> Enum.map(&Ctl.parse/1)
    |> Enum.filter(&Ctl.is_parsed_event?/1)
  end

  test "parsing first testscript" do
    script = script_as_list "test/bluetoothd_script_1.txt"

    assert is_list(script)

    prompt_script = script
    |> Enum.map(&String.split(&1, "#", trim: true))
    |> Enum.filter(fn l -> length(l) == 2 end)

    commands = prompt_script
    |> Enum.filter(fn [_, cmd] -> String.starts_with?(cmd, " ") end)
    |> Enum.map(fn [_, cmd] -> String.trim(cmd) end)

    output = script
    |> Enum.map(&String.split(&1, "#", trim: true))
    |> Enum.filter(fn [_, " " <> cmd] -> false
                      _ -> true end)

    assert length(prompt_script) == 38
    assert length(script) == 191
    assert length(commands) == 18
    assert length(commands) + length(output) == length(script)
    assert ["[bluetooth]", " power on"] = Enum.at(prompt_script, 1)
    assert "power on" = Enum.at(script, 2)
    assert "power on" == Enum.at(commands, 0)
    assert Enum.all?(prompt_script,
        fn [p, _] -> String.ends_with?(p, "[bluetooth]") end)
  end

  test "parse some device states from script 1", %{controller: controller} do
    script = script_as_list "test/bluetoothd_script_1.txt"

    [bluez_start | rest] = script

    tree = Ctl.parse(bluez_start)
    assert {:new, {:controller, "B8:27:EB:CC:05:DA", "BlueZ 5.43 [default]"}} == tree

    power_on = rest
    |> parse_and_filter_commands()
    |> List.first
    assert {:change, {:controller, "B8:27:EB:CC:05:DA", powered: true}} == power_on
  end

  test "manage some device state from script 1 in BLE",  %{controller: controller} do
    script = "test/bluetoothd_script_1.txt"
    |> script_as_list()
    |> parse_and_filter_commands()
    {:ok, ble} = GenBle.start_link(controller)

    assert [] == GenBle.controllers(ble)

    bluez_start = Enum.at(script, 0)
    power_on = Enum.at(script, 1)
    {:new, {:controller, c_id, name}} = bluez_start

    send(ble, bluez_start)
    assert [%GenBle.Controller{id: c_id, name: name, powered: false}] = GenBle.controllers(ble)

    send(ble, power_on)
    assert [%GenBle.Controller{id: c_id, name: name, powered: true}] = GenBle.controllers(ble)
  end

  test "events are stored until the first BLE consummer appears",  %{controller: controller} do
    script = script_as_list("test/bluetoothd_script_1.txt")
    commands = parse_and_filter_commands(script)
    bluez_start = Enum.at(commands, 0)
    {:new, {:controller, c_id, name}} = bluez_start
    # send bluez startup messages to controller
    script
    |> Enum.take(5)
    |> Enum.each(fn input -> send(controller, {:port, {:data, input}}) end)

    # start BLE
    {:ok, ble} = GenBle.start_link() # controller)

    # get Infos about controllers
    assert [%GenBle.Controller{id: ^c_id, name: ^name, powered: true}] = GenBle.controllers(ble)
  end

  test "Process the entire script",  %{controller: controller} do
    script = script_as_list("test/bluetoothd_script_1.txt")
    commands = parse_and_filter_commands(script)
    bluez_start = Enum.at(commands, 0)
    {:new, {:controller, c_id, name}} = bluez_start
    # start BLE
    {:ok, ble} = GenBle.start_link(controller)

    # We use the commands list to prevent synchronization errors,
    # which are still here since sending events is way faster than
    # reacting to them, so it could be that our assert reveals wrong data
    # because we don't wait long enough. This happens immediately
    # if we send the script to the controller, since parsing and
    # sending them to ble takes so much time, that nothing on ble happens
    # before we asking the assertion.

    commands
    |> Enum.each(fn input -> send(ble, input) end)

    # get Info about controllers
    assert [%GenBle.Controller{id: ^c_id, name: ^name, powered: true}] = GenBle.controllers(ble)
  end
end
