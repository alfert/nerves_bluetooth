defmodule Bluetooth.HCI.Event do
  @moduledoc "Struct for a HCI event"

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
  end
  
end
