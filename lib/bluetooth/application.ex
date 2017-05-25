defmodule Bluetooth.Application do
  use Application

  @interface :wlan0
  @kernel_modules Mix.Project.config[:kernel_modules] || []

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # worker(Rpi0Bt.Worker, [arg1, arg2, arg3]),
      # worker(Task, [fn -> init_kernel_modules() end], restart: :transient,
      #     id: Nerves.Init.KernelModules),
      # worker(Task, [fn -> init_network() end], restart: :transient,
      #     id: Nerves.Init.Network),
      # worker(Task, [fn -> init_ntpd() end], restart: :transient, id: :ntpd),
      worker(Task, [&Bluetooth.run_dbus_daemon/0], id: :dbus_daemon),
      worker(Task, [&Bluetooth.run_hciuart/0],
          [id: :hci_uart, restart: :temporary]),
      worker(Task, [&Bluetooth.run_bluetoothd/0], id: :bluetoothd),
      worker(Bluetooth.Ctl, [:power_on])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Rpi0Bt.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def init_kernel_modules() do
    Enum.each(@kernel_modules, & System.cmd("modprobe", [&1]))
  end

  def init_network() do
    opts = Application.get_env(:rpi0_bt, @interface)
    Nerves.InterimWiFi.setup(@interface, opts)
  end

  def init_ntpd() do
    Bluetooth.cmd("/usr/sbin/ntpd", [])
  end

end
