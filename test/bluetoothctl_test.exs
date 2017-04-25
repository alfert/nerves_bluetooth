defmodule Bluetooth.Test.Ctl do

  use ExUnit.Case

  test "parsing first testscript" do
    controller = Bluetooth.Ctl.start(fn -> IO.puts "Hey Hey Hey" end)
    script = "test/bluetoothd_script_1.txt"
    |> File.read!()
    |> String.splitter("\n")
    |> Enum.map(&Bluetooth.Ctl.strip_ansi_sequences/1)

    assert is_list(script)

    prompt_script = script
    |> Enum.map(&String.split(&1, "#", trim: true))
    |> Enum.filter(fn l -> length(l) == 2 end)

    commands = prompt_script
    |> Enum.filter(fn [_, cmd] -> String.starts_with?(cmd, " ") end)
    |> Enum.map(fn [_, cmd] -> String.trim(cmd) end)

    output = script
    |> Enum.map(&String.split(&1, "#", trim: true))
    |> Enum.filter(fn [_, " " <> cmd] -> false
                      _ -> true end)

    assert length(prompt_script) == 38
    assert length(script) == 191
    assert length(commands) == 18
    assert length(commands) + length(output) == length(script)
    assert ["[bluetooth]", " power on"] = Enum.at(prompt_script, 1)
    assert "power on" = Enum.at(script, 2)
    assert "power on" == Enum.at(commands, 0)
    assert Enum.all?(prompt_script,
        fn [p, _] -> String.ends_with?(p, "[bluetooth]") end)
  end

end
