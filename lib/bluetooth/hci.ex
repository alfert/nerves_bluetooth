defmodule Bluetooth.HCI do
  @moduledoc """
  HCI interface implemented as a port.

  ## Approach

  This module implements access to the Bluetooth host-controller-interface (HCI)
  on a Linus-based Bluez-Stack. Since the Erlang VM does not provide access to
  the Bluetooth Socket family, a C port program is used to connect the Erlang VM
  with the Linux Kernel. The port protocol is described in the next section.

  Similar to the UDP socket interface, we provide a for each device a single
  socket controlled by one port program instance and an instance of the HCI
  server. To use HCI you need to provide and/or handle the binary
  representation of commands, events and their parameter sets.  On top of this
  low-level interface high-level interfaces and protocols such as the
  GATT-Services for Bluetooth LE. The functions are closely modeled after
  `noble` in Javascript or `gatt` in Go.

  ## Port Protocol

  The functions are encoded as a tuple with the function name as `atom` and the parameters as an
  (possibly empty) list. All Port functions are prefixed with `hci_`. The call of function `foo(x)`
  would thus transferred as `{:hci_foo, [x]}`. Since the port communication is asynchronous by
  nature and to prevent locks inside the gen server, we use an asynchronous reply and remember
  pending calls inside the gen server. To identify a pending call, a `reference` is created and
  passed to the port. Every replying message must contain this reference. Therefore the message
  send to the port is `{ref, {:hci_foo, [x]}}` and the answer is `{ref, return_val}`.

  ## Initializing the device

  The typical sequence for starting a HCI is:

      {:ok, hci} = HCI.start_server()
      :ok = HCI.init(hci)
      true = HCI.hci_is_dev_up(hci)
      :ok = HCI.hci_bind_raw(hci)
      :ok = HCI.hci_set_filter(hci)

  The `set_filter` function enables all events on the device. Usually this is
  what you want.
  """

  use GenServer
  require Logger
  alias Bluetooth.HCI.Event

  # Constants for HCI commands etc
  @hci_command_package_type 1
  @hci_event_package_type 4


  @doc """
  Opens a bluetooth device for sending and receiving. The only parameter
  is a keyword list of options:

  * `device`: user friendly name of the device (default: `NervesBluetooth`)
  * `emulator`: if set to a pid, it takes the pid as an HCI Port emulator
     to be able to test without hardware access. If not set or `nil`,
     the real hardware device will be accessed (requires currently Linux).
  * `options`: `GenServer` options for `start_link`
  """
  @spec open(Keyword.t) :: {:ok, pid} | {:error, any}
  def open(options \\[device: "NervesBluetooth", emulator: nil]) do
    gen_options = Keyword.get(options, :options, []) #default: empty list
    {:ok, hci} = case Keyword.get(options, :emulator, nil) do
      nil -> start_link(gen_options)
      pid when is_pid(pid) -> start_link(pid, gen_options)
    end
    :ok = hci_init(hci)
    true = hci_is_dev_up(hci)
    0 = hci_bind_raw(hci, 0)
    :ok = hci_set_filter(hci)
    {:ok, hci}
  end

  @doc """
  Starts the HCI socket and the corresponding port process.
  The default options set the name of the process to `__MODULE__`.
  """
  @spec start_link(GenServer.options) :: {:ok, pid} | {:error, any}
  def start_link(opts \\ [name: __MODULE__]) when is_list(opts) do
    case :os.type() do
      {:unix, :linux} -> GenServer.start_link(__MODULE__, [], opts)
      _ -> {:error, "HCI runs only on Linux"}
    end
  end
  def start_link(pid) when is_pid(pid) do
    GenServer.start_link(__MODULE__, [pid], [name: __MODULE__])
  end

  @doc """
  For testing purposes: A port is not started and `pid` is
  an emulator of the regular port.
  """
  @spec start_link(pid, GenServer.options) :: {:ok, pid}
  def start_link(pid, opts)
  def start_link(pid, opts) when is_pid(pid) do
    GenServer.start_link(__MODULE__, [pid], opts)
  end

  @doc """
  Initializes the HCI controller and assign the HCI socket.
  """
  @spec hci_init(GenServer.server) :: :ok | {:error, any}
  def hci_init(hci \\ __MODULE__) do
    GenServer.call(hci, {:hci_init, []})
  end

  @doc """
  Tests whether the device assigned to the HCI process is up
  and running.
  """
  @spec hci_is_dev_up(GenServer.server) :: boolean
  def hci_is_dev_up(hci \\ __MODULE__) do
    GenServer.call(hci, {:hci_is_dev_up, []})
  end

  @doc """
  Returns the device number if the HCI device has state `is_up`. If
  the state does not match, the value `nil` is returned.

  __TODO:__ It is unclear for what reason this function is available
  in the other APIs.
  """
  @spec hci_dev_id_for(GenServer.server, boolean) :: non_neg_integer | nil
  def hci_dev_id_for(hci \\ __MODULE__, is_up) when is_boolean(is_up) do
    GenServer.call(hci, {:hci_dev_id_for, [is_up]})
  end

  @doc """
  Binds the reserved socket to be used for the data transfer with device.
  The numerical device id `dev_id` is required. Returns the device id if the binding
  was successful.
  """
  @spec hci_bind_raw(GenServer.server, non_neg_integer) :: integer
  def hci_bind_raw(hci \\ __MODULE__, dev_id) do
    GenServer.call(hci, {:hci_bind_raw, [dev_id]})
  end

  @doc """
  Sets the filter for events, i.e. to filter out events sent from the
  controller directly inside the controller.

  The filter settings are a binary of 16 bytes (only the first 14 bytes are
  used), decribed in the Bluetooth Spec and the Bluez documentation (see
  `struct hci_filter` in `hci.h` of the Bluez distribution):

    * Bits 0..31: type mask
    * Bits 0..63: bitset of all HCI commands
    * Bits 0..15: opcode
    * 16 Bits: reserved (set to 0)

  The default filter settings are defined in `default_filter()` and enables
  all events.
  """
  @spec hci_set_filter(GenServer.server, binary) :: :ok | {:error, any}
  def hci_set_filter(hci \\ __MODULE__, data \\ default_filter()) do
    GenServer.call(hci, {:hci_set_filter, [data]})
  end

  @doc "Sets the package type to EVENT and allows all event types"
  def default_filter() do
    <<@hci_event_package_type :: size(32)-unsigned-integer,
      0xff, 0xff, 0xff, 0xff,
      0xff, 0xff, 0xff, 0xff,
      0x00, 0x00, 0x00, 0x00>>
  end

  @doc """
  Receives the next event from the HCI device. The `timeout` defines how long
  the current process is suspended for expecting a new event. Default is
  5 seconds. If the caller does not receive the events, they are hold in
  a queue inside `HCI` and returned one by one for each `hci_receive()` call.
  If no events are received within `timeout`, the value `{:error, :timeout}`
  is returned.

  The returned event structure is defined in the Bluetooth Specification
  Vol 2, Section E.5.4.4.
  """
  @spec hci_receive(GenServer.server, non_neg_integer) :: {:ok, Event.t} | {:error, any}
  def hci_receive(hci \\ __MODULE__, timeout \\ 5_000) when is_integer(timeout) and timeout >= 0 do
    GenServer.call(hci, {:hci_receive, [timeout]})
  end

  @doc """
  Send a HCI command to the bluetooth controller. The command `message` is
  a complete binary encoded command. Alternatively, you give the command
  group `ogf` and function `ocf` and the parameters `params`. This is similar to
  using the Bluez `hcitool` utility. The returned value is `:ok` if the
  sending of the command succeeds. All resulting communication from the
  Bluetooth Controller are managed as events.

  Possible commands are defined in the Bluetooth Specification, Vol 2,
  Section E.5.4.1.
  """
  @spec hci_send_command(GenServer.server, binary) :: :ok
  def hci_send_command(hci \\ __MODULE__, message) when is_binary(message) do
    GenServer.call(hci, {:hci_send_command, [message]})
  end
  def hci_send_command(hci \\ __MODULE__, ogf, ocf, params)
  when is_binary(params) and byte_size(params) < 256 and ogf < 64 and ocf < 1024 do
    package = create_command(ogf, ocf, params)
    hci_send_command(hci, package)
  end

  @doc """
  Create the binary representation of a command given by `ogf`, `ocf` and
  parameters `param`. For internal use, but public for testing purposes.
  """
  @doc false
  @spec create_command(non_neg_integer, non_neg_integer, binary) :: binary
  def create_command(ogf, ocf, params)
  when is_binary(params) and byte_size(params) < 256 and ogf < 64 and ocf < 1024 do
    opcode = op_code(ogf, ocf)
    package = <<
      @hci_command_package_type  :: unsigned-integer-size(8),
      opcode :: binary,
      byte_size(params) :: unsigned-integer-size(8)-little,
      params :: binary>>
    Logger.debug "Package is: #{inspect package}"
    package
  end

  @spec op_code(non_neg_integer, non_neg_integer) :: binary
  def op_code(ogf, ocf) do
    opcode_bin = <<
      ogf :: unsigned-integer-size(6),
      ocf :: unsigned-integer-size(10)
    >>
    Logger.debug "opcode: #{inspect opcode_bin}"
    <<opcode :: unsigned-integer-size(16)>> = opcode_bin
    <<opcode :: unsigned-integer-little-size(16)>>
  end

  @doc """
  Creates an event structure from the binary representation.

  For internal use, but public for testing purposes.
  """
  @spec interprete_event(binary) :: Event.t
  def interprete_event(<<@hci_event_package_type :: unsigned-integer-size(8),
      event :: unsigned-integer-size(8),
      len :: unsigned-integer-size(8),
      rest :: binary>> = _event_bin) when len == byte_size(rest),
    do:  %Event{event: event_code(event), parameter: rest}

  @doc """
  Partial mapping of event codes to their atom counterpart
  """
  @spec event_code(non_neg_integer) :: atom | {:hci_unknown_event, non_neg_integer}
  def event_code(0x00), do: :hci_async_event
  def event_code(0x0e), do: :hci_command_complete_event
  def event_code(0x3e), do: :hci_le_meta_event
  def event_code(ev_code), do: {:hci_unknown_event, ev_code}

  @doc """
  Sends a command to the HCI device and waits for the answer.
  It is expected that the next incoming event is the answer of
  the command.
  """
  def sync_command(hci \\ __MODULE__, command) do
    :ok = hci_send_command(hci, command)
    case hci_receive(hci) do
      {:ok, msg} ->
        Logger.debug("sync_command got msg = #{inspect msg}, call Event.decode!")
        Event.decode(msg)
      error -> Logger.error "sync_command got error: #{inspect error}"
        error
    end
  end


  @doc false
  def foo(hci \\ __MODULE__, x) do
    GenServer.call(hci, {:foo, [x]})
  end

  @doc """
  Stops the HCI device.
  """
  @spec stop(GenServer.server) :: :ok
  def stop(hci \\ __MODULE__) do
    GenServer.stop(hci, :normal)
  end

  ###################################################################
  #
  # GenServer Callbacks
  #
  ###################################################################


  @type t :: %__MODULE__{
    port: nil | port,
    calls: %{required(reference) => any},
    messages: :queue.t,
    receiver: nil | pid,
    timer:  nil | reference
  }
  defstruct [port: nil, calls: %{}, messages: :queue.new(), receiver: nil, timer: nil]

  @doc false
  def init([]) do
    Process.flag(:trap_exit, true)
    bin_dir = Application.app_dir(:bluetooth, "priv")
    hci = Path.join(bin_dir, "hci_ex")
    debug = Application.get_env(:bluetooth, :debug)
    Logger.debug "Debug env is #{inspect debug}"
    {exec, args} = case debug do
      :strace -> 
        strace = "/usr/bin/strace"
        args = ["-o", "hci_ex.strace", hci]
        {strace, args}
      :valgrind ->
        valgrind = "/usr/bin/valgrind"
        args = ["--leak-check=yes", "--log-file=hci_ex.val.log", "--xml=yes", "--xml-file=hci_ex.val.xml", hci]
        {valgrind, args}
      _ ->
      {hci, []}
    end

    port = case Port.open({:spawn_executable, exec}, [{:args, args}, {:packet, 2}, :use_stdio, :binary]) do
      p when is_port(p) -> p
    end
    Logger.debug "Port is #{inspect port}"
    state = %__MODULE__{port: port}
    Logger.debug "State will be #{inspect state}"
    {:ok, state}
  end
  def init([pid]) when is_pid(pid) do
    Logger.debug("HCI.init with emulator pid #{inspect pid}")
    state = %__MODULE__{port: pid}
    Logger.debug "State will be #{inspect state}"
    {:ok, state}
  end

  @doc false
  def handle_call({:hci_receive, [timeout]}, from, s = %__MODULE__{messages: q, receiver: nil}) do
    case :queue.out(q) do
      {:empty, ^q} ->
        # set a timer to timeout to wait for a reply
        ref = Process.send_after(self(), {:receive_timeout, from}, timeout)
        # return a noreply message
        {:noreply, %__MODULE__{s | receiver: from, timer: ref}}
        # if a package arrives and a timer is running, abort the timer
        # and send a reply
      {{:value, message}, new_q} ->
        {:reply, {:ok, message}, %__MODULE__{s | messages: new_q}}
    end
  end
  # define a generic encoding and handling, it is not required to
  # differentiate between number of params here!
  def handle_call({func, args} = msg, from, s = %__MODULE__{port: port, calls: c})
      when is_atom(func) and is_list(args) do
    Logger.debug "Call to #{inspect func} with args #{inspect args} in state #{inspect s}"
    # send a message to the port
    ref = make_ref()
    port_msg = {ref, msg} |> :erlang.term_to_binary()
    send(port, {self(), {:command, port_msg}})
    # return without returning, since the port sends a message back later
    {:noreply, %__MODULE__{s | calls: Map.put(c, ref, from)}}
  end

  @doc false
  def handle_info({_port, {:data, msg}}, state) do
    # Logger.error "Unknown message from port: #{inspect msg}"
    new_state = case :erlang.binary_to_term(msg) do
      {:event, event_bin} -> do_handle_event(event_bin, state)
      {ref, return_value} -> do_handle_return_value(ref, return_value, state)
      # _ -> state
    end
    {:noreply, new_state}
  end
  def handle_info({:receive_timeout, from}, state) do
    # write a handle_info for the timeout
    GenServer.reply(from, {:error, :timeout})
    {:noreply, %__MODULE__{state | receiver: nil, timer: nil}}
  end
  def handle_info({:EXIT, _port, :normal}, state) do
    {:stop, :normal, %__MODULE__{state | port: nil}}
  end
  def handle_info({_port, :closed}, _state= %__MODULE__{}) do
    # Port acknowledges the close command
    {:stop, :normal, %__MODULE__{port: nil, calls: %{}}}
  end

  def terminate(reason, _state = %__MODULE__{port: nil}) do
    Logger.debug("HCI is shutting down for reason: #{inspect reason} and port=nil")
    :ok
  end
  def terminate(reason, _state = %__MODULE__{port: port}) do
    Logger.debug("HCI is shutting down for reason: #{inspect reason}")
    # kill the port
    if (is_port(port)),
      do: Port.close(port),
    else: Process.exit(port, :normal)
    :ok
  end

  defp do_handle_return_value(ref, return_value, state = %__MODULE__{calls: calls}) when
  is_reference(ref) do
    # find the caller of the original call to the port
    caller = case Map.get(calls, ref) do
      nil -> "Unknown reference #{inspect ref}"
      pid -> pid
    end
    # send the answer to the original caller
    GenServer.reply(caller, return_value)
    # remove that pending call from the map of pending calls
    %__MODULE__{state | calls: Map.delete(calls, ref)}
  end

  defp do_handle_event(event_bin, state = %__MODULE__{messages: q, receiver: receiver}) do
    event = interprete_event(event_bin)
    Logger.debug "Received event #{inspect event} from binary: #{inspect event_bin}"
    if receiver == nil do
      # enqueue the event
      new_q = :queue.in(event, q)
      %__MODULE__{state | messages: new_q}
    else
      # send the event directly to the waiting process
      Process.cancel_timer(state.timer)
      GenServer.reply(state.receiver, {:ok, event})
      %__MODULE__{state | timer: nil, receiver: nil}
    end
  end

end
