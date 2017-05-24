defmodule Bluetooth.Ctl.Macros do

  defmacro def_switch(name) do
    cmd_name = name
    n = String.to_atom(name)
    quote bind_quoted: [name: n, cmd_name: cmd_name] do
      def unquote(name)(:on), do: cmd(unquote(cmd_name) <> " on\n")
      def unquote(name)(true), do: cmd(unquote(cmd_name) <> " on\n")
      def unquote(name)(:off), do: cmd(unquote(cmd_name) <> " off\n")
      def unquote(name)(false), do: cmd(unquote(cmd_name) <> " off\n")
    end
  end

end
