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

  def write_local_name(name)
  when is_binary(name) and :erlang.byte_size(name) == 248 do
    HCI.create_command(0x03, 0x0015, name)
  end
  def write_local_name(name)
  when is_binary(name) and :erlang.byte_size(name) < 248 do
    HCI.create_command(0x03, 0x0015, name <> <<0>>)
  end

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

  @doc """
  Reads the BD address or the LE public address from the controller
  """
  def read_bd_address() do
    HCI.create_command(0x04, 0x0009, <<>>)
  end

  def receive_bd_address(<<0x00, addr :: binary-size(6)>>), do: {:ok, addr}
  def receive_bd_address(<<code :: unsigned-integer-size(8), _rest::binary>>), do: {:error, code}



end
