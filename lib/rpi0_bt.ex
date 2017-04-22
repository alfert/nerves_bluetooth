defmodule Bluetooth do

  @dbus_pid_dir "/var/run/dbus"
  @dbus_user_id 1_000


  def run_bluetoothd() do
    start_daemon("/usr/libexec/bluetooth/bluetoothd", [])
  end

  def run_hciuart(), do: run_hciuart(5, 5)
  def run_hciuart(n, 0), do: IO.puts("hciattach failed #{n} times. Giving up!")
  def run_hciuart(n, k) do
    case start_daemon("/usr/bin/hciattach",
      ["/dev/ttyAMA0", "bcm43xx", "921600", "noflow", "-"]) do
        0 -> IO.puts("hciattach succeeded!")
        _ -> run_hciuart(n, k - 1)
      end
  end

  @doc """
  Starts the DBUS daemon. Ensures that the dbus pid directory
  exists and is owned by the dbus user.
  """
  def run_dbus_daemon() do
    # ensure that the pid and socket directory is available
    :ok = File.mkdir_p(@dbus_pid_dir)
    :ok = File.chown(@dbus_pid_dir, @dbus_user_id)

    # we use --nofork to prevent a real daemon, which is not controlled
    # by the Erlang VM.
    start_daemon("/usr/bin/dbus-daemon", ["--system", "--nofork"])
  end

  def start_daemon(path, arguments) do
    port = Port.open({:spawn_executable, path}, [:binary, :exit_status, args: arguments])
    receive_port_output(port, path)
  end

  defp receive_port_output(port, path) do
    receive do
      {^port, {:data, data}} ->
        IO.puts("#{path}: #{data}")
        receive_port_output(port, path)
      {^port, {:exit_status, status}} ->
        # the demon has stopped working, so we crash, because
        # the demaon shall run forever. Let the supervisor
        # deal with this situation properly
        status
        # raise("#{path} has stopped working with status #{inspect status}")
    end
  end

  def cmd(prog), do: cmd(prog, [])
  def cmd(prog, param) when is_binary(param), do: cmd(prog, [param])
  def cmd(prog, params) do
    {out, rc} = System.cmd(prog, params, into: IO.stream(:stdio, :line))
  end
end
