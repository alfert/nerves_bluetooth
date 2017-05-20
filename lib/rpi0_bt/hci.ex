defmodule Bluetooth.HCI do
  @moduledoc """
  HCI interface implemented as a port. 

  ## Port Protocol

  The functions are encoded as a tuple with the function name as `atom` and the parameters as an
  (possibly empty) list. All Port functions are prefixed with `hci_`. The call of function `foo(x)`
  would thus transferred as `{:hci_foo, [x]}`. Since the port communication is asynchronous by 
  nature and to prevent locks inside the gen server, we use an asynchronous reply and remember 
  pending calls inside the gen server. To identify a pending call, a `reference` is created and 
  passed to the port. Every replying message must contain this reference. Therefore the message
  send to the port is `{ref, {:hci_foo, [x]}}` and the answer is `{ref, return_val}`.
  """

  use GenServer
  require Logger

  # Constants for HCI commands etc
  @hci_command_package_type 1

  @type hci_event_code_t :: :hci_async_event | :hci_command_complete_event |
    {:hci_unknown_event, pos_integer}

  defmodule Event do
    @moduledoc "Struct for a HCI event"
    @type t :: %__MODULE__{
      event: atom,
      op_code: atom,
      parameter: binary
    }
    defstruct [event: nil, op_code: nil, parameter: ""]
  end
  
  @spec start_link() :: {:ok, pid}
  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  @spec hci_init() :: :ok | {:error, any}
  def hci_init() do
    GenServer.call(__MODULE__, {:hci_init, []})
  end

  @spec hci_is_dev_up() :: boolean
  def hci_is_dev_up() do
    GenServer.call(__MODULE__, {:hci_is_dev_up, []})
  end

  @spec hci_dev_id_for(boolean) :: non_neg_integer | nil
  def hci_dev_id_for(is_up) when is_boolean(is_up) do
    GenServer.call(__MODULE__, {:hci_dev_id_for, [is_up]})
  end

  @spec hci_bind_raw(non_neg_integer) :: integer
  def hci_bind_raw(dev_id) do
    GenServer.call(__MODULE__, {:hci_bind_raw, [dev_id]})
  end
  
  @spec hci_send_command(binary) :: :ok
  def hci_send_command(message) when is_binary(message) do
    GenServer.call(__MODULE__, {:hci_send_command, [message]})
  end
  def hci_send_command(ogf, ocf, params) 
  when is_binary(params) and byte_size(params) < 256 and ogf < 64 and ocf < 1024 do
    package = create_command(ogf, ocf, params)
    hci_send_command(package)
  end  
  
  def create_command(ogf, ocf, params) 
  when is_binary(params) and byte_size(params) < 256 and ogf < 64 and ocf < 1024 do
    opcode_bin = << 
      ogf :: unsigned-integer-size(6),
      ocf :: unsigned-integer-size(10)
    >>
    Logger.debug "opcode: #{inspect opcode_bin}"
    <<opcode :: unsigned-integer-size(16)>> = opcode_bin
    package = <<
      @hci_command_package_type  :: unsigned-integer-size(8),
      opcode :: unsigned-integer-size(16)-little,  
      byte_size(params) :: unsigned-integer-size(8)-little,
      params :: binary>>
    Logger.debug "Package is: #{inspect package}"
    package
  end

  def interprete_event(<<opcode :: unsigned-integer-size(8), 
      event :: unsigned-integer-size(8), 
      len :: unsigned-integer-size(8), 
      rest :: binary>>) when len == byte_size(rest), 
    do:  %Event{event: event_code(event), op_code: opcode, parameter: rest}
  
  @doc """
  Partial mapping of event code to their atom counterpart
  """
  def event_code(0x00), do: :hci_async_event
  def event_code(0x0e), do: :hci_command_complete_event
  def event_code(ev_code), do: {:hci_unknown_event, ev_code}

  def foo(x) do
    GenServer.call(__MODULE__, {:foo, [x]})
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
    port = case Port.open({:spawn_executable, exec}, [{:packet, 2}, :use_stdio, :binary]) do
      p  when is_port(p) -> p
    end
    Logger.debug "Port is #{inspect port}"
    state = %__MODULE__{port: port}
    Logger.debug "State will be #{inspect state}"
    {:ok, state}
  end

  # define a generic encoding and handling, it is not required to 
  # differentiate between number of params here!
  def handle_call({func, args} = msg, from, s = %__MODULE__{port: port, calls: c}) 
      when is_atom(func) and is_list(args) and is_port(port) do
    Logger.debug "Call to #{inspect func} and state #{inspect s}"
    # send a message to the port
    ref = make_ref()
    port_msg = {ref, msg} |> :erlang.term_to_binary()
    send(port, {self(), {:command, port_msg}})
    # return without returning, since the port sends a message back later
    {:noreply, %__MODULE__{s | calls: Map.put(c, ref, from)}}
  end

  def handle_info({port, {:data, msg}}, state = %__MODULE__{calls: calls}) do
    # Logger.error "Unknown message from port: #{inspect msg}"
    new_state = case :erlang.binary_to_term(msg) do
      {ref, return_value} when is_reference(ref) ->
        # find the caller of the original call to the port
        caller = case Map.get(calls, ref) do
          nil -> "Unknown reference #{inspect ref}"
          pid -> pid
        end
        # send the answer to the original caller
        GenServer.reply(caller, return_value)
        # remove that pending call from map of pending calls
        %__MODULE__{state | calls: Map.delete(calls, ref)}
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
    Logger.debug("HCI is shutting down for reason: #{inspect reason} and port=nil")
    :ok
  end
  def terminate(reason, state= %__MODULE__{port: port}) do
    Logger.debug("HCI is shutting down for reason: #{inspect reason}")
    # kill the port
    Port.close(port)
    :ok
  end


end
