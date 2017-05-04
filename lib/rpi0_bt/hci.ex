defmodule Bluetooth.HCI do
  @moduledoc """
  HCI interface implemented as a port
  """

  use GenServer
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def foo(x) do
    GenServer.call(__MODULE__, {:foo, x})
  end

  def bar(x) do
    GenServer.call(__MODULE__, {:bar, x})
  end

  def stop() do
    GenServer.stop(__MODULE__, :normal)
  end

  @type t :: %__MODULE__{
    port: nil | port,
    calls: %{required(reference) => any}
  }
  defstruct [port: nil, calls: %{}]

  def init([]) do
    Process.flag(:trap_exit, true)
    bin_dir = Application.app_dir(:rpi0_bt, "priv")
    exec = Path.join(bin_dir, "hci_ex")
    port = Port.open({:spawn_executable, exec}, [{:packet, 2}, :use_stdio, :binary])
    {:ok, %__MODULE__{port: port}}
  end

  def handle_call({:foo, x} = msg, from, s = %__MODULE__{port: port, calls: c}) do
    # send a message to the port
    ref = make_ref()
    send(port, {self(), {:command, encode_msg(ref, msg)}})
    # return without returning, since the port sends a message back
    {:noreply, %__MODULE__{s | calls: Map.put(c, ref, from)}}
  end

  def encode_msg(ref, {:foo, x}), do: {:foo, ref, x} |> :erlang.term_to_binary()
  def encode_msg(ref, {:bar, x}), do: {:bar, ref, x} |> :erlang.term_to_binary()

  def handle_info({port, {:data, msg}}, state = %__MODULE__{calls: calls}) do
    # Logger.error "Unknown message from port: #{inspect msg}"
    new_state = case :erlang.binary_to_term(msg) do
      {ref, number} when is_reference(ref) ->
        # find the caller of the original call to the port
        caller = case Map.get(calls, ref) do
          nil -> "Unknown reference #{inspect ref}"
          pid -> pid
        end
        # send the answer to the original caller
        GenServer.reply(caller, number)
        # remove that pending call from map of pending calls
        %__MODULE__{calls: Map.delete(calls, ref)}
      # _ -> state
    end
    {:noreply, new_state}
  end
  def handle_info({:EXIT, port, :normal}, state) do
    {:stop, :normal, %__MODULE__{state | port: nil}}
  end
  def handle_info({port, :closed}, state= %__MODULE__{port: port}) do
    # Port acknowledges the close command
    {:stop, :normal, %__MODULE__{port: nil, calls: %{}}}
  end

  def terminate(reason, state= %__MODULE__{port: nil}) do
    :ok
  end
  def terminate(reason, state= %__MODULE__{port: port}) do
    # kill the port
    Port.close(port)
    :ok
  end


end
