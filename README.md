# Nerves Bluetooth

This project enables Bluetooth support for Nerves.

## Bluetooth Spec Abstracts

* Litte Endian, Least Significant Bit first

### List of BLE HCI commands

Sell Vol 2, Section E, 3.1

### HCI Command structure

See  Vol 2, Section E, 5.4.1, figure 5.1, p732

* Maximum length per Command Package 255 bytes excluding HCI command header (3 bytes)
* Command Header:
 * 2 Byte opcode: Opcode Group Field (OFG, upper 6 Bit), Opcode Command Field (OCF, 10 Bit)
 * 1 Byte number of parameter bytes (not parameters!)
 * 0..255 bytes of parameters

### HCI ACL data packages

See  Vol 2, Section E, 5.4.2, figure 5.2, p733

* Maximum length: 27 bytes plus HCI ACL header (4 bytes)
* ACL Header:
 * Handle (lower 12 bit)
 * Packet Boundary Flag (2 bit)
 * Broadcast Flag (2 bit: 00 point2point, 01: active slave broadcast)
 * total data length (16 bit)

### HCI Synchronous Data (HCI SCO, eSCO)
See  Vol 2, Section E, 5.4.3, figure 5.3, p736

### HCI Event Data
See  Vol 2, Section E, 5.4.4, figure 5.4, p738

* Maximal length of 255 bytes plus Event Header (2 byte)
* Event Heder:
  * Event code (1 byte)
  * number of Event parameter bytes (1 byte)

## Targets
Nerves applications are configured that they can produce images for target
hardware by setting `NERVES_TARGET`. By default, if MIX_TARGET is not set, Nerves
defaults to building a host target. This is useful for executing logic tests,
running utilities, and debugging. For more information about targets:
https://hexdocs.pm/nerves/targets.html#content

## Getting Started    

To start your Nerves app:
  * `export NERVES_TARGET=my_target` or prefix every command with `NERVES_TARGET=my_target`, Example: `NERVES_TARGET=rpi3`
  * Install dependencies with `mix deps.get`
  * Create firmware with `mix firmware`
  * Burn to an SD card with `mix firmware.burn`

## Learn more

  * Official docs: https://hexdocs.pm/nerves/getting-started.html
  * Official website: http://www.nerves-project.org/
  * Discussion Slack elixir-lang #nerves ([Invite](https://elixir-slackin.herokuapp.com/))
  * Source: https://github.com/nerves-project/nerves
