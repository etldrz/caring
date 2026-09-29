defmodule Main do
  defstruct [:cmds, :rules, :active_rules, :exp_running?]
  use GenServer
  require Logger

  def initialize(cmds, rules) do
    exp = %Main{cmds: cmds, rules: rules, active_rules: length(rules), exp_running?: false}
    GenServer.start(__MODULE__, exp, name: {:global, :main})
  end

  def stop() do
    GenServer.call({:global, :main}, :stop)
  end

  def run_exp() do
    GenServer.call({:global, :main}, :set_start)
    exp = GenServer.call({:global, :main}, :get_state)
    Enum.each(exp.rules, fn r ->
      GenServer.call({:global, :main}, {:run_rule, r}, :infinity)
    end)
  end

  def get_state() do
    GenServer.call({:global, :main}, :get_state)
  end

  # user initializes, checks for node connectivity and 
  # correct naming are preformed, then experiement is 
  # started seperately.
  @impl true
  def init(exp) do
    nodes =
      [Node.self() | Node.list()]
      |> Map.new(fn n ->
        str = to_string(n)
        {List.first(String.split(str, "@")), n}
      end)

    try do
      new_cmds =
        Enum.map(exp.cmds, fn c ->
          val = nodes[c.target]

          if val do
            %{c | target: val}
          else
            throw(c)
          end
        end)

      exp = %{exp | cmds: new_cmds}

      Enum.each(exp.cmds, fn c ->
        :erpc.cast(c.target, Steward, :start, [c])
      end)

      :net_kernel.monitor_nodes(true, [:nodedown_reason])

      {:ok, exp}
    catch
      c ->
        {:error,
         "Bad node target, '#{c.target}', " <>
           "given in command '#{c.name}'. " <>
           "Check for typos or bad connections. " <>
           "Experiment not initialized."}
    end
  end

  @impl true
  def handle_call(:stop, _from, exp) do
    Enum.each(exp.cmds, fn c ->
      GenServer.stop({:global, c.steward})
    end)

    {:stop, :normal, :ok, exp}
  end

  @impl true
  def handle_call(:set_start, _from, exp) do
    exp = %{exp | exp_running?: true}

    {:reply, exp, exp}
  end

  @impl true
  def handle_call({:run_rule, rule}, _from, exp) do
    CmdAgent.start_agent(rule, nil, nil, exp.cmds)

    {:reply, exp, exp}
  end

  @impl true
  def handle_call(:get_state, _from, exp) do
    {:reply, exp, exp}
  end

  @impl true
  def handle_cast({:set_cmd_status, cmd_status, cmd_name}, exp) do
    cmd_status =
      case cmd_status do
        :ok ->
          :completed

        {:error, exit_status} ->
          :error

        x ->
          x
      end

    status_update =
      Enum.map(exp.cmds, fn c ->
        if c.name === cmd_name do
          %{c | status: cmd_status}
        else
          c
        end
      end)

    exp = %{exp | cmds: status_update}
    # exp = Map.update!(exp, :cmds, fn _ -> status_update end)

    {:noreply, exp}
  end

  @impl true
  def handle_cast(:rule_done, exp) do
    exp =
      if exp.active_rules === 1 do
        %{exp | active_rules: 0, exp_running?: false}
      else
        %{exp | active_rules: exp.active_rules - 1}
      end

    {:noreply, exp}
  end

  @impl true
  def handle_info({:nodeup, node, _info}, state) do
    msg = "Node up: #{node}"
    IO.puts(msg)
    Logger.info(msg)
  end

  @impl true
  def handle_info({:nodedown, node, [{:nodedown_reason, reason}]}, state) do
    msg = "Node down: #{node}, reason: #{reason}"
    IO.puts(msg)
    Logger.info(msg)
  end

  defp call_remote_steward(cmd_id, cmd_data) do
    # stewards can be initialized all at once and then have run called on
    # them globally, also

    Dynamic.Supervisor.start_child(
      ExperimentManager.StewardSupervisor,
      {cmd_id, [cmd_data[:cmd], cmd_data[:opts], cmd_id]}
    )

    # reply = :erpc.cast(cmd_data[:node], Steward, 
    #         :start, [cmd_data[:cmd], cmd_data[:opts], cmd_id])

    # check reply

    GenServer.call({:global, cmd_id}, :run)
  end
end
