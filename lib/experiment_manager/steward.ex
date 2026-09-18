defmodule Steward do
  use GenServer
  require Logger

  def start(cmd, opts, cmd_id) do
    #GenServer.start_link(__MODULE__, {cmd, opts, cmd_id}, name: {:global, cmd_id})
    GenServer.start(__MODULE__, {cmd, opts, cmd_id}, name: {:global, cmd_id})
  end

  # def stop(pid) do
  #   GenServer.stop(pid)
  # end

  # def run_command(pid) do
  #   GenServer.call(pid, :run)
  #   # this returns ok even if the steward is down
  # end

  # def get_log(pid, send_to) do
  #   GenServer.call(pid, {:log_stream, send_to})
  # end

  # here, the command and any additional options are stored into the state
  # for later retrieval and running
  @impl true
  def init({cmd, opts, cmd_id}) do
    state =
      %{
        cmd: cmd,
	cmd_id: cmd_id,
        opts: [:stdout, :stderr, :monitor] ++ opts,
        open_processes: [],
        finished?: false,
        running?: false
      }

    Logger.info("steward initialized")

    {:ok, state}
  end
  

  # starts the given steward, given that no command is already running
  @impl true
  def handle_call(:run, _from, state) do
    if state[:running?] == false do
      :exec.run(state[:cmd], state[:opts])
      Logger.info("steward run starting")
      {:reply, :start_successful, Map.update!(state, :running?, fn _oldvar -> true end)}
    else
      Logger.info("steward run called on already running command")
      {:reply, :already_running, state}
    end
  end

  @impl true
  def handle_call({:log_stream, output_pid}, _from, state) do
    if state[:finished?] do
      {:reply, state[:log], state}
    else
      new_state = Map.update!(state, :open_processes, &[output_pid | &1])
      {:reply, state[:log], new_state}
    end
   end

  @impl true
  def handle_cast({:update_processes, mesg}, state) do
    state[:open_processes]
    |> Enum.each(fn id ->
      if is_pid(id) do
        send(id, mesg)
      else
        # GenServer.cast({:global, {:expnode, id}, {:update_log, mesg, self()})
      end
    end)

    # wipe open_processes if finished?
    {:noreply, state}
  end

  @impl true
  def handle_info({:stdout, ospid, output}, state) do
    entry = [output, source: :stdout, ospid: ospid]
    Logger.info(entry)    
    GenServer.cast({:global, state[:cmd_id]}, {:update_processes, [entry]})

    {:noreply, state}
  end

  @impl true
  def handle_info({:stderr, ospid, output}, state) do
    entry = [output: output, source: :stdout, ospid: ospid]
    Logger.info(entry)
    GenServer.cast({:global, state[:cmd_id]}, {:update_processes, [entry]})
    
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ospid, :process, _pid, :normal}, state) do
    entry = [msg: "process exited normally",
	     ospid: ospid,
	     status: :finished]

    GenServer.cast({:global, state[:cmd_id]}, {:update_processes, {entry, :ok}})
    GenServer.cast({:global, :main}, {:set_cmd_status, :ok, state[:cmd_id]})
    Logger.info(entry)
    {:noreply, Map.update!(state, :finished?, fn _oldvar -> true end)}
  end

  @impl true
  def handle_info({:DOWN, ospid, :process, _pid, {:exit_status, exit_status}}, state) do
    entry = [msg: "process exited with exit status #{exit_status}",
	     ospid: ospid,
	     status: :finished]

    GenServer.cast({:global, state[:cmd_id]}, {:update_processes, {entry, :error}})
    GenServer.cast({:global, :main}, {:set_cmd_status, {:error, exit_status}, state[:cmd_id]})
    Logger.info(entry)
    {:noreply, Map.update!(state, :finished?, fn _oldvar -> true end)}
  end

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
end
