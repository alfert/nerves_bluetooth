defmodule Bluetooth.Ctl do
  @moduledoc """
  This module organizes the communication with `bluetoothctl` to setup
  the `bluez` stack with the devices.
  """
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  @doc """
  Sends `data` synchronously to the port.
  """
  def cmd(data) do
    GenServer.call(__MODULE__, {:cmd, data})
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
