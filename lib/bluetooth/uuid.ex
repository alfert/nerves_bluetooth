defmodule Bluetooth.UUID do
  @moduledoc """
  UUIDs play an important role in Bluetooth (LE). In particular, there
  are shrinked UUIDs to 16 and 32 bits, as well as the 6 byte version of
  device IDs. This module provides functions for UUID manipulation.
  """

  @base_uuid "00000000-0000-1000-8000-00805F9B34FB"
  @base_uuid_postfix "-0000-1000-8000-00805F9B34FB"
  @base_uuid_bin <<0, 0, 0, 0, 0, 0, 16, 0, 128, 0, 0, 128, 95, 155, 52, 251>>
  @base_uuid_postfix_bin    << 0, 0, 16, 0, 128, 0, 0, 128, 95, 155, 52, 251>>

  @doc """
  Create a new random UUID (type 1) with 128 bit with its string representation.
  """
  def uuid128(), do: UUID.uuid1() |> String.upcase

  @doc """
  The Bluetooth base UUID, from which the 16 and 32 bit UUIDs are derived.
  """
  def base_uuid(), do: @base_uuid

  @doc """
  The Bluetooth base UUID as 128 bit binary value, from which the 16 and 32 bit UUIDs are derived.
  """
  def base_uuid_bin(), do: @base_uuid_bin

  @doc """
  Converts a UUID in string form to their binary representation

    iex> string_to_binary!("1234")
    <<0x12, 0x34>>
    iex> string_to_binary!("1234abcd")
    <<0x12, 0x34, 0xab, 0xcd>>
  """
  def string_to_binary!(s) when byte_size(s) == 4 do
    {value, ""} = Integer.parse(s, 16)
    <<value :: integer-unsigned-size(16)>>
  end
  def string_to_binary!(s) when byte_size(s) == 8 do
    {value, ""} = Integer.parse(s, 16)
    <<value :: integer-unsigned-size(32)>>
  end
  def string_to_binary!(s) when byte_size(s) == 36 do
    UUID.string_to_binary!(s)
  end

  @doc """
  Converts a UUID binary into their string representation. This includes
  also the 6 byte UUID of a device. All hex numbers are in upper case.

      iex> binary_to_string!(<<0x1234 :: unsigned-integer-size(16)>>)
      "1234"

      iex> binary_to_string!(<<0xabcd1234 :: unsigned-integer-size(32)>>)
      "ABCD1234"

      iex> binary_to_string!(base_uuid_bin())
      base_uuid()

      iex> binary_to_string!(<<0x1234567890AB :: unsigned-integer-size(48)>>)
      "12:34:56:78:90:AB"
  """
  def binary_to_string!(<<i :: integer-unsigned-size(16)>>),
    do: Integer.to_string(i, 16) |> String.upcase
  def binary_to_string!(<<i :: integer-unsigned-size(32)>>),
    do: Integer.to_string(i, 16) |> String.upcase
  def binary_to_string!(<<_i :: integer-unsigned-size(128)>> = b),
    do: UUID.binary_to_string!(b) |> String.upcase
  def binary_to_string!(b) when is_binary(b) and byte_size(b) == 6 do
    :binary.bin_to_list(b)
    |> Enum.map(fn byte ->
        Integer.to_string(byte, 16) |> String.upcase
      end)
    |> Enum.intersperse(?:)
    |> IO.iodata_to_binary()
  end

  @doc """
  Create the 128 bit UUID from the 16 bit UUID string representation.

      iex> u16 = uuid16_to_uuid128!("1234")
      "00001234-0000-1000-8000-00805F9B34FB"
      iex> uuid128_to_uuid16!(u16)
      "1234"
  """
  def uuid16_to_uuid128!(s) when byte_size(s) == 4 do
    {_val, ""} = Integer.parse(s, 16) # check for correct hex values
    "0000" <> String.upcase(s) <> @base_uuid_postfix
  end

  @doc """
  Create the 128 bit UUID from the 32 bit UUID string representation.

      iex> u32 = uuid32_to_uuid128!("1234abcd")
      "1234ABCD-0000-1000-8000-00805F9B34FB"
      iex> uuid128_to_uuid32!(u32)
      "1234ABCD"
  """
  def uuid32_to_uuid128!(s) when byte_size(s) == 8 do
    {_val, ""} = Integer.parse(s, 16) # check for correct hex values
    String.upcase(s) <> @base_uuid_postfix
  end

  @doc """
  Extracts the 16 bit UUID from the full 128 bit string representation.
  Requires that the suffix uses capital letters.
  """
  def uuid128_to_uuid16!(<<"0000", uuid :: binary-size(4), @base_uuid_postfix>>), do: uuid

  @doc """
  Extracts the 32 bit UUID from the full 128 bit string representation.
  Requires that the suffix uses capital letters.
  """
  def uuid128_to_uuid32!(<<uuid :: binary-size(8), @base_uuid_postfix>>), do: uuid

  @doc """
  Extracts the 32 bit UUID from the full 128 bit representation. Returns
  the binary (4 bytes).
  """
  def uuid128_to_uuid32_bin!(<<uuid :: binary-size(4), @base_uuid_postfix_bin>>), do: uuid

  @doc """
  Extracts the 16 bit UUID from the full 128 bit representation. Returns
  the binary (2 bytes).

    iex> u16 = uuid16_to_uuid128!("1234") |> string_to_binary!
    iex> uuid128_to_uuid16_bin!(u16)
    <<0x12, 0x34>>
  """
  def uuid128_to_uuid16_bin!(<<0, 0, uuid :: binary-size(2), @base_uuid_postfix_bin>>), do: uuid

end
