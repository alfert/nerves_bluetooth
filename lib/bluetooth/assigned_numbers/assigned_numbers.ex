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
end
