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
  def start(fun) when is_function(fun, 0) do
    GenServer.start(__MODULE__, [fun: fun], [name: __MODULE__])
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

  defstruct [port: nil, verbose: true, recording: true, log: nil]

  def init([]) do
    path = System.find_executable("bluetoothctl")
    port = Port.open({:spawn_executable, path},
      [:binary, :use_stdio, :stderr_to_stdout, :stream]) # {:line, 2048}])
    {:ok, %__MODULE__{port: port, log: "/root/bluetoothd.log"}}
  end
  def init([fun: fun]) do
    {:ok, port: fun, recording: false}
  end

  def handle_info({port, {:data, data_string}}, %__MODULE__{verbose: verbose} = state) when
          is_binary(data_string) do
    if verbose, do: IO.puts("BluetoothCtl: #{inspect data_string}")
    data_string
    |> log(state.log)
    |> strip_ansi_sequences()
    |> String.splitter("\n")
    |> Enum.map(&parse/1)
    |> Enum.each(fn p -> IO.puts("Parsed: #{inspect p}") end)
    {:noreply, state}
  end
  def handle_info({port, :closed}, %__MODULE__{verbose: verbose} = state) do
    if verbose, do: IO.puts("BluetoothCtl: closed")
    {:stop, :normal, state}
  end
  def handle_info({port, {:data, data_string}}, %__MODULE__{verbose: verbose} = state) do
    if verbose, do: IO.puts("BluetoothCtl: #{inspect data_string}")
    {:noreply, state}
  end

  def handle_call({:cmd, data}, _from, %__MODULE__{port: port} = state) do
    log(data, state.log)
    Port.command(port, data)
    |> reply(state)
  end

  defp reply(ret_value, state) do
    {:reply, ret_value, state}
  end

  @doc """
  Write the message `msg` to the file with name `filename` and
  returns `msg`.
  """
  def log(msg, filename) do
    :ok = File.write(filename, msg, [:append, :sync, :utf8])
    msg
  end

  @doc """
  Removes the color code ANSI sequences and the `CR` character (`\r`).
  """
  def strip_ansi_sequences(s) do
    color_pattern = "\\e\\[[0-9;]*m"
    clear_line_pattern = "(\\r)|(\\e\\[K)"
    {:ok, regexp} = Regex.compile("(#{color_pattern})|(#{clear_line_pattern})")
    #String.replace(s, regexp, "")
    Regex.replace(regexp, s, "")
  end

  # def parse("[bluetooth]# \r" <> event), do: parse_event(event)
  def parse("[NEW] " <> new_event), do: {:new, parse_device(new_event)}
  def parse("[CHG] " <> chg_event), do: {:change, parse_device(chg_event)}
  def parse(output), do: {output}

  def parse_device(<<"Device ", uuid :: binary-size(17), " ", rest::binary>>) do
    {:device, uuid, rest}
  end
  def parse_device(<<"Controller ", uuid :: binary-size(17), " ", rest::binary>>) do
    {:controller, uuid, rest}
  end
end
