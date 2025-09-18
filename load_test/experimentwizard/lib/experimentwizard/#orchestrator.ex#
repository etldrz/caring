defmodule Experimentwizard.Orchestrator do
  use Agent

  ############# Multiple Procedure Cells #############
  # Cell 1 -> Cell 2 -> Cell 3 ...
  # Need result cells... single command
  #
  def start_link(name) do
    full_name = String.to_atom(name <> "Orchestrator")
    Agent.start_link(fn -> [] end, name: full_name)
  end

  ############# Procedure Cell #############
  # target: single node or multiple nodes
  # experiment_commands: (sequential)
  # variables:
  # "ls @{var1}"
  # "iperf3 @{var2}"
  # @{var1} = [-a, -l, -a -l]


  # Stacks vs parallel


  @doc """
  Create a new procedure cell, target_list and commands_list both must be lists.
  commands will be executed in sequential orders.
  Evaluation order: setup -> commands -> stacked -> teardown -> next
  """
  def procedure_cell(synchronous \\ true, concurrency \\ false, target_list, commands_list, output \\ false) do
    %{
      synchronous: synchronous,
      concurrency: concurrency,
      target: target_list,
      commands: commands_list,
      output: output,
      setup_cell: nil,
      teardown_cell: nil,
      stacked_cell: nil
    }
  end

  def add_setup(procedure_cell, target_list, commands_list) do
    Map.put(procedure_cell, :setup_cell,
    %{
      target: target_list,
      commands: commands_list
    })
  end

  def add_teardown(procedure_cell, target_list, commands_list) do
    Map.put(procedure_cell, :teardown_cell,
    %{
      target: target_list,
      commands: commands_list
    })
  end

  def add_cell(orchestrator, cell) do
    Agent.update(orchestrator, fn state -> state ++ [cell] end)
  end

  def add_stacked_cell_to(new_stack_cell, target_cell) do
    Map.update!(target_cell, :stacked_cell, fn _value -> new_stack_cell end)
  end

  def get_orchestrator_state(orchestartor) do
    Agent.get(orchestartor, fn state -> state end)
  end

  def clear_orchestrator(orchestrator) do
    Agent.update(orchestrator, fn _value -> [] end)
  end

  def run_orchestrator(orchestartor, vars_map \\ %{}) do
    # TODO: Use a scheduler to do the work
    Agent.get(orchestartor, fn state -> state end) |>
    Enum.map(fn
      cell ->
        run_cell_commands(cell, vars_map) |> List.flatten()
      end)
  end

  def run_cell_commands(cell, vars_map) do
    # First, try replace variables and generate replaced commands
    replaced_commands = replace_vars(cell.commands, vars_map)
    # Using double for loop to run all commands on all nodes.
    run_setup(cell, vars_map)
    result_list =
      Enum.map(cell.target, fn
        each_node ->
          Enum.map(replaced_commands, fn
          each_command ->
            if !cell.synchronous do
              # Maybe use task to enable concurrency?
              # Then sequential execution is not guaranteed...
              Experimentwizard.Executer.run_async_command(each_node, each_command)
            else
              Experimentwizard.Executer.run_sync_command(each_node, each_command)
            end
          end)
      end)
      # If the output is not needed, return empty list, which will be removed later.
    cond do
      cell.stacked_cell && cell.output ->
        result_list = result_list ++ run_cell_commands(cell.stacked_cell, vars_map)
        run_teardown(cell, vars_map)
        result_list
      cell.stacked_cell && !cell.output ->
        result_list = run_cell_commands(cell.stacked_cell, vars_map)
        run_teardown(cell, vars_map)
        result_list
      !cell.stacked_cell && cell.output ->
        run_teardown(cell, vars_map)
        result_list
      !cell.stacked_cell && !cell.output ->
        run_teardown(cell, vars_map)
        []
    end
  end

  defp run_setup(cell, vars_map) do
    setup_cell = cell.setup_cell
    if setup_cell != nil do
      run_subcell_commands(setup_cell, vars_map)
    end
  end

  defp run_teardown(cell, vars_map) do
    teardown_cell = cell.teardown_cell
    if teardown_cell != nil do
      run_subcell_commands(teardown_cell, vars_map)
    end
  end

  defp run_subcell_commands(sub_cell, vars_map) do
    replaced_commands = replace_vars(sub_cell.commands, vars_map)
    Enum.each(sub_cell.target, fn
      each_node ->
        Enum.each(replaced_commands, fn
         each_command ->
            Experimentwizard.Executer.run_sync_command(each_node, each_command)
          end)
      end)
  end

  # Return a list of variables, if any, from a command.
  defp extract_vars(command) do
    Regex.scan(~r/\@\{[\w\d]+\}/, command)
    |> List.flatten()
    |> Enum.map(fn each_match -> String.slice(each_match, 2..-2) end)
  end

  defp replace_vars(commands_list, value_map) do
    Enum.map(commands_list, fn each_command ->
      vars = extract_vars(each_command)
      replace_var(each_command, vars, value_map)
    end)
  end

  defp replace_var(command, var_list, var_map) do
    if Enum.any?(var_list) do
      [head | tail] = var_list
      value = Map.get(var_map, head)
      if is_bitstring(value) do
        command = String.replace(command, "@{" <> head <> "}", value)
        replace_var(command, tail, var_map)
      else
        command = String.replace(command, "@{" <> head <> "}", Kernel.inspect(value))
        replace_var(command, tail, var_map)
      end
    else
      command
    end
  end
end

defmodule ExpTask do
  defstruct [name: nil, vars: %{}, repeat: 1, on_error: :restart_task, results: [], procedures: []]

  # Rewrite name
  def name(struct, new_name) do
    Map.put(struct, :name, new_name)
  end

  # Rewrite vars
  def vars(struct, new_vars) do
    Map.put(struct, :vars, new_vars)
  end

  # Rewrtie repeat
  def repeat(struct, new_repeat) do
    Map.put(struct, :repeat, new_repeat)
  end

  # Rewrite on error action
  def on_error(struct, new_action) do
    Map.put(struct, :on_error, new_action)
  end

  # Append to results
  def results(struct, new_results) do
    Map.update!(struct, :results, fn value -> value ++ [new_results] end)
  end

  # Append to procedures, if given procedures is a list
  def procedures(struct, new_procedures) when is_list(new_procedures) do
    Map.update!(struct, :procedures, fn value -> value ++ new_procedures end)
  end

  # Append to procedures, if the given procedure is not a list
  def procedures(struct, new_procedures) do
    Map.update!(struct, :procedures, fn value -> value ++ [new_procedures] end)
  end

  # Run the task n times according to the repeat variable.
  def run(struct) do
    for each_run <- 1..struct.repeat, do: {each_run,
    Enum.map(struct.procedures, fn
      each_cell ->
        Experimentwizard.Orchestrator.run_cell_commands(each_cell, struct.vars) |> List.flatten()
    end)
  }
  end

end
