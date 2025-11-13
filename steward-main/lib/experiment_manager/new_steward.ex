defmodule Steward do
  use GenServer

  # client 

  def start_link() do
    GenServer.start_link(__MODULE__, %{})
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  def run_command(pid, cmd, opts \\ []) when is_binary(cmd) do
    capture_out = [:stdout, :stderr, :monitor]
    opts = capture_out ++ opts

    # this returns ok even if the steward is down
    GenServer.cast(pid, {:run, cmd, opts})
  end

  def get_log(pid) do
    GenServer.call(pid, :log_stream)
  end

  # server

  @impl true
  def init(start_arg) do
    state =
      start_arg
      |> Map.put(:log, [[output: "steward initialized", timestamp: current_time()]])
      |> Map.put(:open_processes, [])
      |> Map.put(:finished?, false)

    {:ok, state}
  end

  @impl true
  def handle_cast({:run, cmd, opts}, state) do
    :exec.run(cmd, opts)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_processes, mesg}, state) do
    state[:open_processes] |> Enum.each(fn pid -> send(pid, mesg) end)
    # wipe open_processes if finished?
    {:noreply, state}
  end

  @impl true
  def handle_info({:stdout, ospid, output}, state) do
    entry = [source: :stdout, output: output, ospid: ospid, timestamp: current_time()]
    GenServer.cast(self(), {:update_processes, [entry]})
    # {:noreply, Map.update!(state, :log, &(&1 ++ state[:open_processes]))}
    {:noreply, Map.update!(state, :log, &(&1 ++ [entry]))}
  end

  @impl true
  def handle_info({:stderr, ospid, output}, state) do
    entry = [source: :stderr, output: output, ospid: ospid, timestamp: current_time()]
    GenServer.cast(self(), {:update_processes, [entry]})
    {:noreply, Map.update!(state, :log, &(&1 ++ [entry]))}
  end

  @impl true
  def handle_info({:DOWN, ospid, :process, _pid, :normal}, state) do
    entry = [
      output: "process exited normally",
      ospid: ospid,
      timestamp: current_time()
    ]

    new_state =
      state
      |> Map.update!(:finished?, fn _oldvar -> true end)
      |> Map.update!(:log, &(&1 ++ [[entry], :ok]))

    GenServer.cast(self(), {:update_processes, {entry, :ok}})
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, ospid, :process, _pid, {:exit_status, exit_status}}, state) do
    entry = [
      output: "process exited with exit status #{exit_status}",
      ospid: ospid,
      timestamp: current_time()
    ]

    new_state =
      state
      |> Map.update!(:finished?, fn _oldvar -> true end)
      |> Map.update!(:log, &(&1 ++ [[entry], :error]))

    GenServer.cast(self(), {:update_processes, {entry, :error}})
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:log_stream, {from_pid, _}, state) do
    if state[:finished?] == true do
      {:reply, state[:log], state}
    else
      # task = Task.async(fn -> log_stream(state[:log]) end)
      # stream = Task.await(task)
      new_state = Map.update!(state, :open_processes, &[from_pid | &1])
      {:reply, log_stream(state[:log]), new_state}
    end
  end

  # helper funs

  # this does not receive messages when any process other than the original calling process
  # accesses it
  defp log_stream(log) do
    Stream.resource(
      fn -> log end,
      fn log ->
        case log do
          :done ->
            {:halt, []}

          [] ->
            receive do
              {item, :ok} -> {[item, :ok], :done}
              {item, :error} -> {[item, :error], :done}
              resp -> {resp, []}
            end

          items ->
            {items, []}
        end
      end,
      fn _ -> :ok end
    )
  end

  defp current_time() do
    Time.utc_now() |> Time.to_iso8601()
  end
end
