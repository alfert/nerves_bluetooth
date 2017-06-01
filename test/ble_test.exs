defmodule Bluetooth.Test.BLE do

  use ExUnit.Case
  alias Bluetooth.GenBLE
  alias Bluetooth.HCI.PortEmulator


  test "start the virtual BLE device" do
    {:ok, emulator} = PortEmulator.start_link()
    {:ok, ble} = GenBLE.start_link(emulator: emulator)
    assert is_pid(ble)

    uuid = GenBLE.device_id(ble)

    assert uuid == "AC:BC:32:95:6D:68"
  end

end
