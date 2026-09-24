defmodule Main do
  use GenServer
  require Logger

  def start(cmds, rules) do
    exp = %{cmds: cmds, rules: rules, exp_runing?: false}
    GenServer.start(__MODULE__, exp, name: {:global, :main})
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
      Node.list()
      |> Map.new(fn n -> {List.first(String.split(n, "@")), n} end)

    try do
      exp[:cmds] =
        Enum.map(exp[:cmds], fn c ->
          val = nodes[c.target]
          if val do
            %{c | target: val}
          else
            throw(c)
          end
        end)

      :net_kernel.monitor_nodes(true, [:nodedown_reason])

      {:ok, exp}
    catch
      c -> {:error, "Bad node name given in command \n#{inspect(c)}"}
    end
  end

  def run_exp(exp) do
    GenServer.call({:global, :main}, :run_exp)
  end

  @impl true
  def handle_cast({:update_cmds, cmd_status, cmd_name}, exp) do
    cmd_status =
      case status do
        :ok ->
          :completed

        {:error, exit_status} ->
          :error
          # error handling goes here
      end

    ## everything past here assumes an :ok response

    exp[:cmds] =
      Enum.map(exp[:cmds], fn c ->
        if c.name === finished_cmd_name do
          %{c | status: cmd_status}
        else
          c
        end
      end)

    {:noreply, exp}
  end

  @impl true
  def handle_call(:get_state, _from, exp) do
    {:reply, exp, exp}
  end

  @impl true
  def handle_call(:run_exp, exp) do
    if length(no_deps) == 0 do
      {:reply, :bad_exp_description, state}
    else
      # here, we can put in constraints to limit the flow of nodes and/or cmds, see make -j
      no_deps |> Enum.each(fn c_id -> call_remote_steward(c_id, state[:exp][c_id]) end)
      {:reply, :exp_initiated, Keyword.replace(state, :exp_running?, true)}
    end
  end

  # @impl true
  # def handle_call({:change_exp, new_exp}, state) do
  #   if state[:exp_running? == true] do
  #     {:reply, {:error, "Experiment already running"}, state}
  #   else
  #     new_state = [cmds: get_cmds(exp), exp: new_exp, exp_running?: false]
  #     {:reply, :ok, new_state}
  #   end
  # end

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
