defmodule Bluetooth.HCI.PortEmulator do
  @moduledoc """
  Emulates the port program for accessing HCI and enables testing
  on a host without accessing a real bluetooth device.

  """

  use GenServer
  require Logger
  alias Bluetooth.HCI

  # Constants for HCI commands etc
  @hci_command_package_type 1
  @hci_1_package 1
  @hci_event_package_type 4
  @hci_command_complete_event 0x0e

  def start_link(hci_device \\ 0) do
    GenServer.start_link(__MODULE__, [hci_device])
  end

  defstruct [hci_device: -1, filter: "", from: nil]

  def init([hci_device]) do
    {:ok, %__MODULE__{hci_device: hci_device}}
  end

  def handle_info({from, {:command, msg}}, state) when is_pid(from) and is_binary(msg) do
    {ref, {func, args}} = :erlang.binary_to_term(msg)
    state = %__MODULE__{state | from: from}
    {new_state, result} = apply(__MODULE__, func, [state | args])
    return_value = :erlang.term_to_binary({ref, result})
    send(from, {self(), {:data, return_value}})
    {:noreply, new_state}
  end

  def hci_init(state) do
    {state, :ok}
  end

  def hci_is_dev_up(state) do
    {state, true}
  end

  def hci_dev_id_for(state, true), do: {state, state.hci_device}
  def hci_dev_id_for(state, false), do: {state, nil}

  def hci_bind_raw(%__MODULE{hci_device: id} = state, dev_id) when dev_id == id do
    {state, dev_id}
  end
  def hci_bind_raw(state, _) , do: {state, -1}

  def hci_set_filter(state, filter_data) do
    new_state = %__MODULE__{state | filter: filter_data}
    {new_state, :ok}
  end

  def hci_send_command(state, command) do
    <<@hci_command_package_type :: integer-size(8),
      opcode :: unsigned-integer-little-size(16),
      len :: unsigned-integer-size(8),
      params :: binary>> = command
    <<
      ogf :: unsigned-integer-size(6),
      ocf :: unsigned-integer-size(10)
    >> = <<opcode :: unsigned-integer-size(16)>>
    do_command(ogf, ocf, params, state)
  end

  def do_command(0x03, 0x01, <<>>, state) do
    Logger.debug "Emulator: Reseting"
    msg = <<@hci_1_package>> <> op_code(3, 1) <> <<0>>
    do_send_msg(state.from, msg)
    {state, :ok}
  end
  def do_command(0x03, 0x014, <<>>, state) do
    Logger.debug "Emulator: read local name"
    msg = <<@hci_1_package>> <> op_code(0x03, 0x014) <> <<0, "HCI Emulator", 0>>
    do_send_msg(state.from, msg)
    {state, :ok}
  end
  def do_command(0x04, 0x01, <<>>, state) do
    Logger.debug "Emulator: Local version info"
    msg = <<@hci_1_package>> <> op_code(04, 01) <> << 0, 7, 25, 18, 7, 15, 0, 119, 33>>
    do_send_msg(state.from, msg)
    {state, :ok}
  end
  def do_command(0x04, 0x09, <<>>, state) do
    device_uuid = <<104, 109, 149, 50, 188, 172>>
    opcode = <<@hci_1_package>>  <> op_code(4, 9) <> <<0>> # , 9, 16, 0 >>
    msg = opcode <> device_uuid
    do_send_msg(state.from, msg)
    {state, :ok}
  end
  def do_command(ogf, ocf, params, state) do
    Logger.error "#{__MODULE__}: Unknown command: ogf: #{inspect ogf}, ocf: #{inspect ocf}, params: #{inspect params}"
    {:stop, {:error, :unknown_command}, state}
  end

  def do_send_msg(pid, msg) do
    do_send_event(pid, <<@hci_event_package_type, @hci_command_complete_event, byte_size(msg)>> <> msg)
  end

  def do_send_event(pid, data) do
    msg = :erlang.term_to_binary({:event, data})
    send(pid, {self(), {:data, msg}})
  end

  @spec op_code(non_neg_integer, non_neg_integer) :: binary
  def op_code(ogf, ocf) do
    opcode_bin = <<
      ogf :: unsigned-integer-size(6),
      ocf :: unsigned-integer-size(10)
    >>
    Logger.debug "opcode: #{inspect opcode_bin}"
    # opcode_bin
    <<opcode :: unsigned-integer-size(16)>> = opcode_bin
    <<opcode :: unsigned-integer-little-size(16)>>
  end

  def foo(state, x) do
    {state, x+1}
  end
end
