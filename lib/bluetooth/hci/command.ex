defmodule Bluetooth.HCI.Commands do
  @moduledoc """
  This module holds conversion functions for HCI commands and their results
  from and to a logical format and the binary representation.

  This module does not to attempt to be complete but grows by need.
  """
  alias Bluetooth.HCI

  ####################################################################
  #
  # Link Level Commands (ogf = 00x03)
  #
  ####################################################################

  def reset(), do: HCI.create_command(0x03, 0x01, <<>>)

  def read_local_name(), do: HCI.create_command(0x03, 0x0014, <<>>)

  def write_local_name(name)
  when is_binary(name) and :erlang.byte_size(name) == 248 do
    HCI.create_command(0x03, 0x0015, name)
  end
  def write_local_name(name)
  when is_binary(name) and :erlang.byte_size(name) < 248 do
    HCI.create_command(0x03, 0x0015, name <> <<0>>)
  end
  
  ####################################################################
  #
  # Information Parameter Commands (ogf = 00x04)
  #
  ####################################################################


  def read_local_version_info() do
    HCI.create_command(0x04, 0x01, <<>>)
  end

  @doc """
  Reads the BD address or the LE public address from the controller
  """
  def read_bd_address() do
    HCI.create_command(0x04, 0x0009, <<>>)
  end




end
