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

  @doc "Maps error code to the error messages"
  def error_string(0x00), do: "Success"
  def error_string(0x01), do: "Unknown HCI Command"
  def error_string(0x02), do: "Unknown Connection Identifier"
  def error_string(0x03), do: "Hardware Failure"
  def error_string(0x04), do: "Page Timeout"
  def error_string(0x05), do: "Authentication Failure"
  def error_string(0x06), do: "PIN or Key Missing"
  def error_string(0x07), do: "Memory Capacity Exceeded"
  def error_string(0x08), do: "Connection Timeout"
  def error_string(0x09), do: "Connection Limit Exceeded"
  def error_string(0x0A), do: "Synchronous Connection Limit To A Device Exceeded"
  def error_string(0x0B), do: "Connection Already Exists"
  def error_string(0x0C), do: "Command Disallowed"
  def error_string(0x0D), do: "Connection Rejected due to Limited Resources"
  def error_string(0x0E), do: "Connection Rejected Due To Security Reasons"
  def error_string(0x0F), do: "Connection Rejected due to Unacceptable BD_ADDR"
  def error_string(0x10), do: "Connection Accept Timeout Exceeded"
  def error_string(0x11), do: "Unsupported Feature or Parameter Value"
  def error_string(0x12), do: "Invalid HCI Command Parameters"
  def error_string(0x13), do: "Remote User Terminated Connection"
  def error_string(0x14), do: "Remote Device Terminated Connection due to Low Resources"
  def error_string(0x15), do: "Remote Device Terminated Connection due to Power Off"
  def error_string(0x16), do: "Connection Terminated By Local Host"
  def error_string(0x17), do: "Repeated Attempts"
  def error_string(0x18), do: "Pairing Not Allowed"
  def error_string(0x19), do: "Unknown LMP PDU"
  def error_string(0x1A), do: "Unsupported Remote Feature / Unsupported LMP Feature"
  def error_string(0x1B), do: "SCO Offset Rejected"
  def error_string(0x1C), do: "SCO Interval Rejected"
  def error_string(0x1D), do: "SCO Air Mode Rejected"
  def error_string(0x1E), do: "Invalid LMP Parameters / Invalid LL Parameters"
  def error_string(0x1F), do: "Unspecified Error"
  def error_string(0x20), do: "Unsupported LMP Parameter Value / Unsupported LL Parameter Value"
  def error_string(0x21), do: "Role Change Not Allowed"
  def error_string(0x22), do: "LMP Response Timeout / LL Response Timeout"
  def error_string(0x23), do: "LMP Error Transaction Collision / LL Procedure Collision"
  def error_string(0x24), do: "LMP PDU Not Allowed"
  def error_string(0x25), do: "Encryption Mode Not Acceptable"
  def error_string(0x26), do: "Link Key cannot be Changed"
  def error_string(0x27), do: "Requested QoS Not Supported"
  def error_string(0x28), do: "Instant Passed"
  def error_string(0x29), do: "Pairing With Unit Key Not Supported"
  def error_string(0x2A), do: "Different Transaction Collision"
  def error_string(0x2B), do: "Reserved for Future Use"
  def error_string(0x2C), do: "QoS Unacceptable Parameter"
  def error_string(0x2D), do: "QoS Rejected"
  def error_string(0x2E), do: "Channel Classification Not Supported"
  def error_string(0x2F), do: "Insufficient Security"
  def error_string(0x30), do: "Parameter Out Of Mandatory Range"
  def error_string(0x31), do: "Reserved for Future Use"
  def error_string(0x32), do: "Role Switch Pending"
  def error_string(0x33), do: "Reserved for Future Use"
  def error_string(0x34), do: "Reserved Slot Violation"
  def error_string(0x35), do: "Role Switch Failed"
  def error_string(0x36), do: "Extended Inquiry Response Too Large"
  def error_string(0x37), do: "Secure Simple Pairing Not Supported By Host"
  def error_string(0x38), do: "Host Busy - Pairing"
  def error_string(0x39), do: "Connection Rejected due to No Suitable Channel Found"
  def error_string(0x3A), do: "Controller Busy"
  def error_string(0x3B), do: "Unacceptable Connection Parameters"
  def error_string(0x3C), do: "Advertising Timeout"
  def error_string(0x3D), do: "Connection Terminated due to MIC Failure"
  def error_string(0x3E), do: "Connection Failed to be Established"
  def error_string(0x3F), do: "MAC Connection Failed"
  def error_string(0x40), do: "Coarse Clock Adjustment Rejected but Will Try to Adjust Using Clock Dragging"
  def error_string(0x41), do: "Type0 Submap Not Defined"
  def error_string(0x42), do: "Unknown Advertising Identifier"
  def error_string(0x43), do: "Limit Reached"
  def error_string(0x44), do: "Operation Cancelled by Host"

end
