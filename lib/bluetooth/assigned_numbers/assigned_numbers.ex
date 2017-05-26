defmodule Bluetooth.AssignedNumbers do

  @external_resource company_json = Path.join([__DIR__, "json", "company-identifier.json"])
  @external_resource uuid_member = Path.join([__DIR__, "json", "16bit-uuid-member.json"])
  # Create the company names from the company-identifiers.json file
  @doc "Maps the company id to the company long name"
  for [s_id, _, name] <- (company_json
        |> File.read!()
        |> Poison.decode!()
        |> Map.get("data")) do
          {id, _} = Integer.parse(s_id)
          # IO.puts "Generate for id #{id} value #{name}"
          def company_name(unquote(id)), do: unquote(name)
        end

  @doc "Maps the 16bit UUID of Bluetooth SIG Member to their long name"
  for [s_id, _, name, _] <- (uuid_member
        |> File.read!()
        |> Poison.decode!()
        |> Map.get("data")) do
          {id, _} = Integer.parse(s_id)
          # IO.puts "Generate for id #{id} value #{name}"
          def member_name(unquote(id)), do: unquote(name)
        end


  @doc """
  Maps the version number to their long name
  """
  def version(0), do: "Bluetooth Core Specification 1.0b"
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
