defmodule Bluetooth.GenBLE do

  use GenServer
  require Logger

  alias Bluetooth.HCI
  alias Bluetooth.HCI.Commands

  @type t :: GenServer.server

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, [debug: [:log]])
  end

  @spec device_id(t) :: String.t
  def device_id(dev) do
    dev
    |> GenServer.call({:get_dev_id})
    |> Bluetooth.UUID.binary_to_string!()
  end

  @spec local_name(t) :: String.t
  def local_name(dev) do
    dev
    |> GenServer.call(:local_name)
  end

  @spec set_local_name(t, String.t) :: :ok | {:error, any}
  def set_local_name(dev, name) when is_binary(name) and byte_size(name) <= 248 do
    GenServer.call(dev, {:set_local_name, name})
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

  defstruct [device_id: "", devices: %{}, hci: nil, name: ""]

  def init(opts) do
    emu = Keyword.get(opts, :emulator)
    {:ok, hci} = HCI.open([device: "NervesBluetooth", emulator: emu])
    # :ok = HCI.sync_command(hci, Commands.reset())
    {:ok, dev_id} = HCI.sync_command(hci, Commands.read_bd_address())
    {:ok, name} = HCI.sync_command(hci, Commands.read_local_name())
    {:ok, %__MODULE__{hci: hci, device_id: dev_id, name: name}}
  end

  def handle_call(:devices, _from, state = %__MODULE__{devices: ds}) do
    Map.values(ds)
    |> reply(state)
  end
  def handle_call({:get_dev_id}, _from, state = %__MODULE__{device_id: dev_id}) do
    reply(dev_id, state)
  end
  def handle_call(:local_name, _from, state = %__MODULE__{name: name}) do
    reply(name, state)
  end
  def handle_call({:set_local_name, new_name}, _from, state = %__MODULE__{hci: hci}) do
    case HCI.sync_command(hci, Commands.write_local_name(new_name)) do
      :ok -> 
        {:ok, name} = HCI.sync_command(hci, Commands.read_local_name())
        if (name == new_name) do
          %__MODULE__{state | name: new_name} |> ok()
        else
          Logger.error "BLE name is #{inspect name}, not set to #{inspect new_name}"
          reply({:error, :new_name_is_not_set}, state)
        end
      error -> reply(error, state)
    end
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
