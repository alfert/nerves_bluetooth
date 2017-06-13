defmodule Bluetooth.HCI.Event do
  @moduledoc "Struct for a HCI event"

  require Logger

  alias Bluetooth.HCI.Commands
  alias Bluetooth.AssignedNumbers
  # Constants for HCI commands etc
  @hci_command_package_type 1
  @hci_event_package_type 4
  @hci_le_meta_event 0x3e


  @type hci_event_code_t :: nil | :hci_async_event | :hci_command_complete_event |
    :hci_le_meta_event |
    {:hci_unknown_event, pos_integer}

  @type t :: %__MODULE__{
    event: hci_event_code_t,
    parameter: binary
  }
  defstruct [event: nil, parameter: ""]

  defmodule CommandComplete do
    @moduledoc """
    A command complete event in more detail to get access to the real
    result parameters of the command
    """
    @type t :: %__MODULE__{
      packets: non_neg_integer,
      ogf: non_neg_integer,
      ocf: non_neg_integer,
      parameter: binary
    }
    defstruct packets: 0, ogf: 0, ocf: 0, parameter: ""
  end

  defmodule LEMetaEvent do
    @moduledoc """
    The BLE Meta Evant encapsule all BLE events
    """

    defstruct [sub_event: 0, parameter: ""]

  end

  def decode(%__MODULE__{event: :hci_command_complete_event, parameter: p}) do
    <<packets :: unsigned-integer-size(8),
      opcode :: unsigned-integer-little-size(16),
      params :: binary>> = p
    <<
      ogf :: unsigned-integer-size(6),
      ocf :: unsigned-integer-size(10)
    >> = <<opcode :: unsigned-integer-size(16)>>
    %CommandComplete{packets: packets, parameter: params, ogf: ogf, ocf: ocf}
    |> command_event()
  end

  @doc """
  A first attempt to convert generic command events into more
  specific events.
  """
  def command_event(0x03, 0x0001, params), do: decode_reset(params)
  def command_event(0x03, 0x0014, params), do: decode_local_name(params)
  def command_event(0x04, 0x0009, params), do: decode_bd_address(params)
  def command_event(0x04, 0x0001, params), do: decode_local_version_info(params)
  def command_event(%CommandComplete{ogf: ogf, ocf: ocf, parameter: params} = m) do
    Logger.debug("command event of #{inspect m}")
    command_event(ogf, ocf, params)
  end

  ##########
  #
  # TODO:
  # * decoding of events => monomorphic to the final structure
  # * Implement BLE in small parts incrementally
  #   -> Apple's BluetoothCore-API as an example
  #   -> Advertising, LE Scan, Remote-Name of Devices, Public-Addresses
  #
  ##########

  ####################################################################
  #
  # Link Level Commands (ogf = 00x03)
  #
  ####################################################################

  def decode_reset(<<0>>), do: :ok
  def decode_reset(<<code :: integer-size(8), _>>), do: {:error, code}

  def decode_local_name(<<0 :: size(8), long_name :: binary>>) do
    # the local name is 0-terminated or a full 248 bytes long UTF8 string
    [name, _] = String.split(long_name, <<0>>, parts: 2)
    {:ok, name}
  end
  def decode_local_name(<<code :: integer-size(8), _>>), do: {:error, code}

  def decode_local_version_info(params) do
    <<code :: integer-size(8),
      hci_version :: integer-size(8),
      hci_revision :: integer-little-size(16),
      pal_version :: integer-size(8),
      manufacturer :: integer-little-size(16),
      pal_subversion :: integer-little-size(16)
      >> = params
      if (code != 0) do
        {:error, code}
      else
        {:ok, %{hci_version_code: hci_version,
          hci_version: AssignedNumbers.version(hci_version),
          hci_revision: hci_revision,
          pal_version_code: pal_version,
          pal_version: AssignedNumbers.version(pal_version),
          manufacturer_uuid: manufacturer,
          manufacturer: AssignedNumbers.company_name(manufacturer),
          pal_subversion: pal_subversion
        }}
      end
  end

  def decode_bd_address(<<0x00, addr :: binary-size(6)>>), do: {:ok, addr}
  def decode_bd_address(<<code :: unsigned-integer-size(8), _rest::binary>>), do: {:error, code}

end
