defmodule Bluetooth.Ctl do
  @moduledoc """
  This module organizes the communication with `bluetoothctl` to setup
  the `bluez` stack with the devices.
  """
  use GenServer
  require Bluetooth.Ctl.Macros
  alias Bluetooth.Ctl.Macros

  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end
  def start() do
    GenServer.start(__MODULE__, [], [name: __MODULE__])
  end

  def quit, do: cmd("quit")
  def help, do: cmd("help")
  def version, do: cmd("version")
  def list, do: cmd("list")
  def devices, do: cmd("devices")

  Macros.def_switch("scan")
  Macros.def_switch("power")
  Macros.def_switch("pairable")
  Macros.def_switch("discoverable")
  Macros.def_switch("notify")

  @doc """
  Sends `data` synchronously to the port.
  """
  def cmd(data) do
    cmd = if String.ends_with?(data, "\n") do
      data
    else
      data <> "\n"
    end
    GenServer.call(__MODULE__, {:cmd, cmd})
  end

  defstruct [port: nil, verbose: true]

  def init([]) do
    path = System.find_executable("bluetoothctl")
    port = Port.open({:spawn_executable, path},
      [:binary, :use_stdio, :stderr_to_stdout, :stream])
    {:ok, %__MODULE__{port: port}}
  end

  def handle_info({port, {:data, data}}, %__MODULE__{verbose: verbose} = state) do
    if verbose, do: IO.puts("BluetoothCtl: #{data}")
    {:noreply, state}
  end
  def handle_info({port, :closed}, %__MODULE__{verbose: verbose} = state) do
    if verbose, do: IO.puts("BluetoothCtl: closed")
    {:stop, :normal, state}
  end

  def handle_call({:cmd, data}, _from, %__MODULE__{port: port} = state) do
    Port.command(port, data)
    |> reply(state)
  end

  defp reply(ret_value, state) do
    {:reply, ret_value, state}
  end
end
