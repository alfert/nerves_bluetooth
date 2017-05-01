defmodule Bluetooth.GenBle do

  use GenServer
  alias Bluetooth.Ctl, as: Driver
  require Logger

  def start_link(driver \\ GenServer.whereis(Driver)) when is_pid(driver) do
    GenServer.start_link(__MODULE__, [driver], [debug: [:log]])
  end

  def controllers(ble) do
    GenServer.call(ble, :controllers)
  end

  defstruct [:driver, :monitor_ref, controllers: %{}, devices: %{}]

  defmodule Controller do
    @moduledoc """
    Data structure describing a controller and its state
    """
    @type t :: %__MODULE__{id: String.t, name: String.t, powered: boolean,
      discovering: boolean, discoverable: boolean}
    defstruct [id: "", name: "", powered: false, discovering: false,
      discoverable: false]
  end

  defmodule Device do
    @moduledoc """
    Data structure descibring a device and its (generic) state
    """
    @type t :: %__MODULE__{id: String.t, name: String.t, rssi: integer}
    defstruct [id: "", name: "", rssi: 0]
  end

  def init([driver]) do
    ref = Process.monitor(driver)
    Driver.attach(driver, self())
    {:ok, %__MODULE__{driver: driver, monitor_ref: ref}}
  end

  def handle_call(:controllers, _from, state = %__MODULE__{controllers: cs}) do
    Map.values(cs)
    |> reply(state)
  end

  def handle_info({:events, events}, state) when is_list(events) do
    # iterate through all events to calculate the state
    Logger.debug "Got a sequence of events: #{inspect events}"
    final_state = Enum.reduce(events, state, fn ev, s ->
      {:noreply, s_new} = handle_info(ev, s)
      s_new
    end)
    {:noreply, final_state}
  end
  def handle_info({:new, {:device, id, name}}, state = %__MODULE__{devices: ds}) do
    d = %Device{id: id, name: name}
    Logger.info "New controller: #{inspect d}"
    {:noreply, %__MODULE__{state | devices: Map.put(ds, id, d)}}
  end
  def handle_info({:change, {:device, id, attributes}}, state = %__MODULE__{devices: ds}) do
    case Map.get(ds, id) do
      nil -> Logger.error("Unknown device #{id}")
      d ->
        new_d = struct!(d, attributes)
        {:noreply,  %__MODULE__{state | devices: Map.put(ds, id, new_d)}}
    end
  end
  def handle_info({:new, {:controller, id, name}}, state = %__MODULE__{controllers: cs}) do
    c = %Controller{id: id, name: name}
    Logger.info "New controller: #{inspect c}"
    {:noreply, %__MODULE__{state | controllers: Map.put(cs, id, c)}}
  end
  def handle_info({:change, {:controller, id, attributes}}, state = %__MODULE__{controllers: cs}) do
    case Map.get(cs, id) do
      nil -> Logger.error("Unknown controller #{id}")
      c ->
        new_c = struct!(c, attributes)
        {:noreply,  %__MODULE__{state | controllers: Map.put(cs, id, new_c)}}
    end
  end
  def handle_info({:DOWN, ref, :process, _pid, _}, state = %__MODULE__{monitor_ref: m_ref}) when ref == m_ref do
    Logger.info("Driver #{inspect state.driver} is down")
    {:stop, :driver_down, state}
  end
  # def handle_info(msg, state) when is_tuple(msg) do
  #   Logger.error "GenBle.handle_info: Ignoring unknown message #{inspect msg}"
  #   {:noreply, state}
  # end

  defp reply(ret_value, state) do
    {:reply, ret_value, state}
  end

  defp ok(state), do: reply(:ok, state)
end
