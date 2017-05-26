defmodule Bluetooth.HCI.Commands do
  @moduledoc """
  This module holds conversion functions for HCI commands and their results
  from and to a logical format and the binary representation.

  This module does not to attempt to be complete but grows by need.
  """
  alias Bluetooth.HCI
  alias Bluetooth.AssignedNumbers

  def read_local_name() do
    HCI.create_command(0x03, 0x0014, <<>>)
  end

  def receive_local_name(<<0 :: size(8), long_name :: binary>>) do
    # the local name is 0-terminated or a full 248 bytes long UTF8 string
    [name, _] = String.split(long_name, <<0>>, parts: 2)
    {:ok, name}
  end
  def receive_local_name(<<code :: integer-size(8), _>>), do: {:error, code}

  def read_local_version_info() do
    HCI.create_command(0x04, 0x01, <<>>)
  end

  def receive_local_version_info(params) do
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
          hci_version: version(hci_version),
          hci_revision: hci_revision,
          pal_version_code: pal_version,
          pal_version: version(pal_version),
          manufacturer_uuid: manufacturer,
          manufacturer: AssignedNumbers.company_name(manufacturer),
          pal_subversion: pal_subversion
        }}
      end
  end

  def version(0), do: "Bluetooth® Core Specification 1.0b"
  def version(1), do: "Bluetooth Core Specification 1.1"
  def version(2), do: "Bluetooth Core Specification 1.2"
  def version(3), do: "Bluetooth Core Specification 2.0 + EDR"
  def version(4), do: "Bluetooth Core Specification 2.1 + EDR"
  def version(5), do: "Bluetooth Core Specification 3.0 + HS"
  def version(6), do: "Bluetooth Core Specification 4.0"
  def version(7), do: "Bluetooth Core Specification 4.1"
  def version(8), do: "Bluetooth Core Specification 4.2"
  def version(9), do: "Bluetooth Core Specification 5.0"
  def version(_), do: "Reserved"

end
