defmodule Bluetooth.GenBLE do

  use GenServer
  require Logger

  alias Bluetooth.HCI
  alias Bluetooth.HCI.Commands

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, [debug: [:log]])
  end

  def device_id(dev) do
    {:ok, id} = GenServer.call(dev, {:get_dev_id})
    Bluetooth.UUID.binary_to_string!(id)
  end

    @doc """
  Creates an iBeacon advertisement with `major` and `minor` values
  """
  def iBeacon(uuid \\ "b2a21ef4-2e71-11e7-b18b-acbc32956d67", _major, _minor) do
    Driver.cmd("set-advertise-uuids #{uuid}")
    Driver.cmd("set-advertise-manufacturer 76") # 76 = 0x004c Apple
    Driver.cmd("set-advertise-service FF")
    Driver.cmd("set-advertise-tx-power on")
    Driver.cmd("advertise on")
  end

  defstruct [device_id: "", devices: %{}, hci: nil]

  def init(opts) do
    emu = Keyword.get(opts, :emulator)
    {:ok, hci} = HCI.open([device: "NervesBluetooth", emulator: emu])
    :ok = HCI.sync_command(hci, Commands.reset())
    dev_id = HCI.sync_command(hci, Commands.read_bd_address())
    {:ok, %__MODULE__{hci: hci, device_id: dev_id}}
  end

  def handle_call(:devices, _from, state = %__MODULE__{devices: ds}) do
    Map.values(ds)
    |> reply(state)
  end
  def handle_call({:get_dev_id}, _from, state = %__MODULE__{device_id: dev_id}) do
    reply(dev_id, state)
  end

  def handle_info(msg, state) when is_tuple(msg) do
    Logger.error "GenBle.handle_info: Ignoring unknown message #{inspect msg}"
    {:noreply, state}
  end

  defp reply(ret_value, state) do
    {:reply, ret_value, state}
  end

  defp ok(state), do: reply(:ok, state)


end
