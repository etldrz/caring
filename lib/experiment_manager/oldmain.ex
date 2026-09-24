# defmodule Main do
#   use GenServer
#   require Logger

#   def start(exp) do
#     GenServer.start(__MODULE__, exp, name: {:global, :main})
#   end

#   def get_state() do
#     GenServer.call({:global, :main}, :get_state)
#   end

#   def run_exp(exp) do
#     GenServer.call({:global, :main}, :run_exp)
#   end

#   # user initializes, checks for node connectivity are
#   # preformed, then experiement is started seperately
#   @impl true
#   def init(exp) do
#     :net_kernel.monitor_nodes(true, [:nodedown_reason])

#     cmd_deps =
#       exp[:cmds]
#       |> Enum.filter(fn {_c_id, c_data} ->
#         length(c_data[:deps]) > 0
#       end)
#       |> Enum.map(fn {c_id, c_data} ->
#         {c_id, c_data[:deps]}
#       end)

#     # possible cmd_status atoms
#     # :queued, :running, :completed, :error
#     cmd_status =
#       Enum.map(
#         exp[:cmds],
#         fn {c_id, _c_data} ->
#           {c_id, :queued}
#         end
#       )

#     {:ok, [cmd_status: cmd_status, cmd_deps: cmd_deps, exp: exp, exp_running?: false]}
#   end

#   @impl true
#   def handle_cast({:update_cmds, status, finished_cmd_id}, state) do
#     new_cmd_status =
#       case status do
#         :ok ->
#           :completed

#         {:error, exit_status} ->
#           :error
#           # error handling goes here
#       end

#     ## everything past here assumes an :ok response

#     # update deps, if its empty for some cmd then run that command
#     {new_cmd_deps, cmds_to_run} =
#       state[:cmd_deps]
#       |> Enum.map(fn {c_id, c_deps} ->
#         {c_id, List.delete(c_deps, finished_cmd_id)}
#       end)
#       |> Enum.split_with(fn {_c_id, c_deps} ->
#         length(c_deps) > 0
#       end)

#     cmds_to_run
#     |> Enum.each(fn {c_id, _c_deps} ->
#       call_remote_steward(c_id, state[:exp][:cmds][c_id])
#     end)

#     new_cmd_status =
#       state[:cmd_status]
#       |> Enum.map(fn {c_id, s} ->
#         cond do
#           c_id == finished_cmd_id -> {c_id, new_cmd_status}
#           c_id in cmds_to_run -> {c_id, :running}
#           true -> {c_id, s}
#         end
#       end)

#     new_state = [
#       cmd_status: new_cmd_status,
#       cmd_deps: new_cmd_deps |> Enum.filter(fn {_c_id, c_deps} -> length(c_deps) > 0 end),
#       exp: state[:exp],
#       exp_running?: true
#     ]

#     {:noreply, new_state}
#   end

#   @impl true
#   def handle_call(:get_state, _from, state) do
#     {:reply, state, state}
#   end

#   @impl true
#   def handle_call(:run_exp, state) do
#     no_deps =
#       Keyword.keys(state[:cmds])
#       |> Enum.filter(fn c_id -> c_id not in Keyword.keys(state[:deps]) end)

#     if length(no_deps) == 0 do
#       {:reply, :bad_exp_description, state}
#     else
#       # here, we can put in constraints to limit the flow of nodes and/or cmds, see make -j
#       no_deps |> Enum.each(fn c_id -> call_remote_steward(c_id, state[:exp][c_id]) end)
#       {:reply, :exp_initiated, Keyword.replace(state, :exp_running?, true)}
#     end
#   end

#   # @impl true
#   # def handle_call({:change_exp, new_exp}, state) do
#   #   if state[:exp_running? == true] do
#   #     {:reply, {:error, "Experiment already running"}, state}
#   #   else
#   #     new_state = [cmds: get_cmds(exp), exp: new_exp, exp_running?: false]
#   #     {:reply, :ok, new_state}
#   #   end
#   # end

#   @impl true
#   def handle_info({:nodeup, node, _info}, state) do
#     msg = "Node up: #{node}"
#     IO.puts(msg)
#     Logger.info(msg)
#   end

#   @impl true
#   def handle_info({:nodedown, node, [{:nodedown_reason, reason}]}, state) do
#     msg = "Node down: #{node}, reason: #{reason}"
#     IO.puts(msg)
#     Logger.info(msg)
#   end

#   defp call_remote_steward(cmd_id, cmd_data) do
#     # stewards can be initialized all at once and then have run called on
#     # them globally, also

#     Dynamic.Supervisor.start_child(
#       ExperimentManager.StewardSupervisor,
#       {cmd_id, [cmd_data[:cmd], cmd_data[:opts], cmd_id]}
#     )

#     # reply = :erpc.cast(cmd_data[:node], Steward, 
#     #         :start, [cmd_data[:cmd], cmd_data[:opts], cmd_id])

#     # check reply

#     GenServer.call({:global, cmd_id}, :run)
#   end
# end
