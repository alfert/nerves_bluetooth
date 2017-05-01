defmodule Bluetooth.Ctl do
  @moduledoc """
  This module organizes the communication with `bluetoothctl` to setup
  the `bluez` stack with the devices.
  """
  use GenServer
  require Bluetooth.Ctl.Macros
  require Logger
  alias Bluetooth.Ctl.Macros
  alias Bluetooth.GenBle

  def start_link(:power_on) do
    return_val = start_link()
    true = power :on
    return_val
  end
  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__, debug: [:log]])
  end
  def start() do
    GenServer.start(__MODULE__, [], [name: __MODULE__, debug: [:log]])
  end
  def start(fun) when is_function(fun, 0) do
    GenServer.start(__MODULE__, [fun: fun], [name: __MODULE__, debug: [:log]])
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

  @doc """
  Attaches a BLE manager to the bluetooth control process and
  sends all already parsed event messages from bluez to the
  BLE such that both states become identical.
  """
  def attach(_ctl, ble) do
    GenServer.call(__MODULE__, {:attach, ble})
  end

  defstruct [port: nil, verbose: true, recording: true, log: nil, ble: nil,
    event_queue: :queue.new()]

  def init([]) do
    path = System.find_executable("bluetoothctl")
    port = Port.open({:spawn_executable, path},
      [:binary, :use_stdio, :stderr_to_stdout, :stream]) # {:line, 2048}])
    {:ok, %__MODULE__{port: port, log: "/root/bluetoothd.log"}}
  end
  def init([fun: fun]) do
    {:ok,  %__MODULE__{port: fun, recording: false}}
  end

  def handle_info({port, {:data, data_string}}, state = %__MODULE__{verbose: verbose, event_queue: q}) when
          is_binary(data_string) do
    if verbose, do: Logger.info("BluetoothCtl: #{inspect data_string}")

    new_q = data_string
    |> log(state.log)
    |> strip_ansi_sequences()
    |> String.splitter("\n")
    |> Enum.map(&parse/1)
    |> Enum.filter(&is_parsed_event?/1)
    |> Enum.map(fn p ->
      Logger.info("Parsed: #{inspect p}")
      p
    end)
    |> Enum.map(fn p ->
      if (state.ble != nil), do: send(state.ble, p)
      p
    end)
    |> Enum.reduce(q, fn event, ev_q ->
      if (state.ble == nil), do: :queue.in(event, ev_q), else: ev_q end)
    {:noreply, struct(state, [event_queue: new_q])}
  end
  def handle_info({port, :closed}, %__MODULE__{verbose: verbose} = state) do
    if verbose, do: Logger.info("BluetoothCtl: closed")
    {:stop, :normal, state}
  end
  def handle_info({port, {:data, data_string}}, %__MODULE__{verbose: verbose} = state) do
    if verbose, do: Logger.info("BluetoothCtl: #{inspect data_string}")
    {:noreply, state}
  end

  def handle_call({:cmd, data}, _from, %__MODULE__{port: port} = state) do
    log(data, state.log)
    Port.command(port, data)
    |> reply(state)
  end
  def handle_call({:attach, ble}, _from, state) do
    send(ble, {:events, :queue.to_list(state.event_queue)})
    new_state = %__MODULE__{state | ble: ble, event_queue: :queue.new()}
    reply(:ok, new_state)
  end

  defp reply(ret_value, state) do
    {:reply, ret_value, state}
  end

  @doc """
  Write the message `msg` to the file with name `filename` and
  returns `msg`.
  """
  def log(msg, nil) do
    Logger.debug "Ignoring log recording: #{msg}"
    msg
   end
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

  def is_parsed_event?({:new, _}), do: true
  def is_parsed_event?({:change, _}), do: true
  def is_parsed_event?(_), do: false

  def parse("[NEW] " <> new_event), do: {:new, parse_device(new_event)}
  def parse("[CHG] " <> chg_event), do: {:change, parse_device(chg_event)}
  def parse(output) do
    case String.split(output, "[bluetooth]#", parts: 2) do
      [_prefix, cmd] -> parse(cmd)
      [_] -> {output}
    end
  end

  def parse_device(<<"Device ", uuid :: binary-size(17), " ", rest::binary>>) do
    {:device, uuid, device_state(rest)}
  end
  def parse_device(<<"Controller ", uuid :: binary-size(17), " ", rest::binary>>) do
    {:controller, uuid, controller_state(rest)}
  end

  def controller_state("Powered: " <> "yes"), do: [powered: true]
  def controller_state("Powered: " <> "no"), do: [powered: false]
  def controller_state("Discovering: " <> "yes"), do: [discovering: true]
  def controller_state("Discovering: " <> "no"), do: [discovering: false]
  def controller_state("Discoverable: " <> "yes"), do: [discoverable: true]
  def controller_state("Discoverable: " <> "no"), do: [discoverable: false]
  def controller_state(any_state), do: any_state

  def device_state("RSSI: " <> number), do: [rssi: Integer.parse(number, 10)]
  def device_state(any_state), do: any_state


end
