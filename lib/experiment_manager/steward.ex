defmodule Steward do
  use GenServer
  require Logger

  defstruct [:cmd, :opts, :open_processes, :agent_requests, :finished?, :running?, :success?]

  def start(cmd) do
    GenServer.start(__MODULE__, cmd, name: {:global, cmd.steward})
  end

  @impl true
  def init(cmd) do
    state =
      %Steward{
        cmd: cmd,
        opts: [:stdout, :stderr, :monitor],
        open_processes: MapSet.new(),
        agent_requests: MapSet.new(),
        finished?: false,
        running?: false,
        success?: nil
      }

    Logger.info("#{state.cmd.steward} initialized")

    {:ok, state}
  end

  @impl true
  def handle_call(:run, {from, _tag}, state) do
    if state.running? == false do
      GenServer.cast(
        {:global, :main},
        {:set_cmd_status, :running, state.cmd.name}
      )

      :exec.run(state.cmd.body, state.opts)
      Logger.info("#{state.cmd.steward} run starting")

      new_state =
        %{state | running?: true, agent_requests: MapSet.put(state.agent_requests, from)}

      {:reply, :ok, new_state}
    else
      Logger.info("steward run called on already running command")
      {:reply, {:error, :already_started}, state}
    end
  end

  @impl true
  def handle_cast({:update_agent, from}, state) do
    if state.finished? do
      Agent.cast(
        from,
        fn agent_state ->
          CmdAgent.finished_on_node(
            agent_state,
            state.cmd,
            state.success?
          )
        end
      )

      {:noreply, state}
    else
      new_state =
        %{state | agent_requests: MapSet.put(state.agent_requests, from)}

      Logger.info(
        "steward #{state.cmd.steward} is adding agent " <>
          "#{inspect(from)} to its update list"
      )

      {:noreply, new_state}
    end
  end

  @impl true
  def handle_call({:log_stream, output_pid}, _from, state) do
    if state.finished? do
      {:reply, state.log, state}
    else
      {:reply, Map.update!(state, :open_processes, &[output_pid | &1])}
    end
  end

  @impl true
  def handle_cast({:update_processes, mesg}, state) do
    # state[:open_processes]
    # |> Enum.each(fn id ->
    #   if is_pid(id) do
    #     send(id, mesg)
    #   else
    #     # GenServer.cast({:global, {:expnode, id}, {:update_log, mesg, self()})
    #   end
    # end)

    # wipe open_processes if finished?
    {:noreply, state}
  end

  @impl true
  def handle_info({:stdout, ospid, output}, state) do
    entry = [output, source: :stdout, ospid: ospid]

    Logger.info(
      "#{state.cmd.steward} outputed to stdout with " <>
        "output #{output}"
    )

    GenServer.cast(self(), {:update_processes, [entry]})

    {:noreply, state}
  end

  @impl true
  def handle_info({:stderr, ospid, output}, state) do
    entry = [output: output, source: :stdout, ospid: ospid]

    Logger.info(
      "#{state.cmd.steward} outputted to stderr with " <>
        "output #{output}"
    )

    GenServer.cast(self(), {:update_processes, [entry]})

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ospid, :process, _pid, :normal}, state) do
    entry = [msg: "process exited normally", ospid: ospid, status: :finished]

    Logger.info(
      "#{state.cmd.steward} exited normally and will " <>
        "update appropriate agents"
    )

    GenServer.cast(self(), {:update_processes, {entry, :ok}})
    GenServer.cast({:global, :main}, {:set_cmd_status, :ok, state.cmd.name})

    Enum.each(
      state.agent_requests,
      fn agent ->
        Agent.cast(
          agent,
          fn agent_state ->
            CmdAgent.finished_on_node(agent_state, state.cmd, :ok)
          end
        )
      end
    )

    {:noreply, %{state | finished?: true, success?: :ok}}
  end

  @impl true
  def handle_info({:DOWN, ospid, :process, _pid, {:exit_status, exit_status}}, state) do
    entry = [
      msg: "process exited with exit status #{exit_status}",
      ospid: ospid,
      status: :finished
    ]

    GenServer.cast(self(), {:update_processes, {entry, :error}})
    GenServer.cast({:global, :main}, {:set_cmd_status, {:error, exit_status}, state.cmd_id})

    Enum.each(
      state.agent_requests |> MapSet.to_list(),
      fn agent ->
        Agent.cast(
          agent,
          fn agent_state ->
            CmdAgent.finished_on_node(agent_state, state.cmd, :ok)
          end
        )
      end
    )

    Logger.info(
      "#{state.cmd.steward} exited to stderr with " <>
        "exit status #{exit_status}"
    )

    {:noreply, %{state | finished?: true, success?: :error}}
  end

  # this does not receive messages when any process other than the original calling process
  # accesses it
  # defp log_stream(log) do
  #   Stream.resource(
  #     fn -> log end,
  #     fn log ->
  #       case log do
  #         :done ->
  #           {:halt, []}

  #         [] ->
  #           receive do
  #             {item, :ok} -> {[item, :ok], :done}
  #             {item, :error} -> {[item, :error], :done}
  #             resp -> {resp, []}
  #           end

  #         items ->
  #           {items, []}
  #       end
  #     end,
  #     fn _ -> :ok end
  #   )
  # end
end
