defmodule Bluetooth.GenBle do

  use GenServer
  alias Bluetooth.Ctl, as: Driver
  require Logger

  def start_link(driver \\ GenServer.whereis(Driver)) when is_pid(driver) do
    GenServer.start_link(__MODULE__, [], [debug: [:log]])
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

  defstruct [device_id: "", devices: %{}]

  def init([]) do
    {:ok, %__MODULE__{}}
  end

  def handle_call(:devices, _from, state = %__MODULE__{devices: ds}) do
    Map.values(ds)
    |> reply(state)
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
