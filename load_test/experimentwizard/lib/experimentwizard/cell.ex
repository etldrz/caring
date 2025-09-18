defmodule Experimentwizard.Cell do
  # TODO:
  # Maybe add support for dumping data/results out after a breakpoint is reached. (Debugger actions)
  # Add supervisors for cell failing (Could be a stack), which is also user defined
  # Easier representation of the underlying data structure? A graph???
  # Think about other experiments that could automate using the prototype. Firewall, VLAN, etc.
  #
  # Evaluation order: setup -> commands -> teardown
  defstruct name: nil,
            on_error: nil,
            synchronous: true,
            output: false,
            repeat: 1,
            vars: %{},
            targets: [],
            commands: [],
            # Could be a list of cells.
            # next_cell: [],
            setup: nil,
            teardown: nil,
            # This allows the result of this cell to be bind to a specific variable.
            binds_to: nil,
            # For special conditional cells
            is_conditional: false,
            # Let the test_clause be "equals" or "contains"
            test_clause: "",
            thn_cell: nil,
            els_cell: nil,
            set_env: nil

  ####### Syntactic sugar for the pipe operator #######

  # Rewrite name
  def name(struct, new_name) do
    Map.put(struct, :name, new_name)
  end

  # Rewrite on error action
  def on_error(struct, new_action) do
    Map.put(struct, :on_error, new_action)
  end

  def synchronous(struct, new_sync) do
    Map.put(struct, :synchronous, new_sync)
  end

  def output(struct, new_output) do
    Map.put(struct, :output, new_output)
  end

  # Rewrite repeat
  def repeat(struct, new_repeat) do
    Map.put(struct, :repeat, new_repeat)
  end

  # Rewrite vars
  def vars(struct, new_vars) do
    Map.put(struct, :vars, new_vars)
  end

  # Rewrite targets
  def targets(struct, new_targets) do
    Map.put(struct, :targets, new_targets)
  end

  # Rewrite commands
  def commands(struct, new_commands) do
    Map.put(struct, :commands, new_commands)
  end

  # Rewrite setup cell
  def setup(struct, setup_cell) do
    Map.put(struct, :setup, setup_cell)
  end

  # Rewrite teardown cell
  def teardown(struct, teardown_cell) do
    Map.put(struct, :teardown, teardown_cell)
  end

  # Rewrite teardown cell
  def binds_to(struct, new_binding) do
    Map.put(struct, :binds_to, new_binding)
  end

  # Rewrite set_env
  def set_env(struct, env) do
    Map.put(struct, :set_env, env)
  end

  ####### Interpreter code #######

  # This function recursively evaluate the cells until there's no more next cell.

  ### TODO: Maybe change the return of run_cell function so that env could be passed around and it could be cleaned up!!!
  ### TODO: Also refine recursion to cover base cases.

  def resume(env, graph) do
    # Manually evaluate the breakpoint cell.
    next_vertex = Map.get(env, :next_vertex)
    traverse_graph(next_vertex, graph, env)
  end

  ####### Private Helper Functions #######


  # The reason to have a graph: each cell representation does not have all the necessary information
  # for the graph to determine running path.
  # Also for easier code writing and management.
  # Let the last vertex of graph does not have any out neighbor.
  def traverse_graph(vertex, graph, env) do
    # A vertex != a cell
    cell = find_cell(vertex, env)
    next = find_out_vertex(graph, vertex, :next)
    on_error = find_out_vertex(graph, vertex, :on_error)
    then_v = find_out_vertex(graph, vertex, :then_v)
    else_v = find_out_vertex(graph, vertex, :else_v)
    pre_breakpoints = Map.get(env, :pre_breakpoints)
    post_breakpoints = Map.get(env, :post_breakpoints)
    cond do
      # First, check it is the end vertex, if it is, end.
      Graph.out_neighbors(graph, vertex) |> Enum.empty?() ->
        env

      # if cell is nil then it means it is a super vertex, then go to the next vertex
      cell == nil ->
        traverse_graph(next, graph, env)

      # Then check if the pre-breakpoint is reached.
      MapSet.member?(pre_breakpoints, cell.name) && env[:next_vertex] != cell.name ->
        IO.puts("Pre breakpoint at \'" <> cell.name <> "\' is reached.")
        Map.replace!(env, :next_vertex, cell.name)

              # And check if it conditional
      cell.is_conditional ->
        check_conditional(cell.name, graph, env)

      cell.set_env != nil ->
        desired_env = Map.get(env, String.to_atom(cell.set_env))
        IO.inspect(desired_env)
        targets = cell.targets
        IO.inspect(targets)
        update_env(targets, desired_env)
        traverse_graph(next, graph, env)

      true ->
        # Now run cell.
        # If there's an error the result will be an error instead of a string.
        result = run_cell_commands(cell, env)
        env =
          Map.update!(env, :results, fn old_results ->
            Map.put(old_results, cell.name, result)
          end)

        # After running the cell, need to check if the post breakpoint is reached.

        cond do
          MapSet.member?(post_breakpoints, cell.name) ->
            IO.puts("Post breakpoint at \'" <> cell.name <> "\' is reached.")
            IO.inspect(vertex)
            Map.replace!(env, :next_vertex, next)

          is_exception(result) ->
            # Retry after 5 second
            Process.sleep(5000)
            error_count = Map.get(env, :error_count)
            if error_count <= 10 do
              traverse_graph(on_error, graph, Map.update!(env, :error_count, fn x -> x + 1 end))
            else
              raise("Too many retries.")
            end
          true ->
            # check if needs to bind the result first
            # and update the result
            flattened_result = List.flatten(result)
            # result = List.foldl(flattened_result, "", fn x, acc -> acc <> x end)
            # |> String.replace("\n", "")
            env =
              if cell.binds_to != nil do
                # IO.puts("In binding")
                # IO.inspect(flattened_result)
                Map.update!(env, :vars, fn old_vars ->
                  Map.put(old_vars, cell.binds_to, Enum.at(flattened_result,0))
                end)
              else
                env
              end

            # Now go to the next vertex in the graph.
            traverse_graph(next, graph, env)
        end
    end
  end

  defp check_conditional(vertex, graph, env) do
    then_v = find_out_vertex(graph, vertex, :then_v)
    else_v = find_out_vertex(graph, vertex, :else_v)
    cell = find_cell(vertex, env)
    # Assume all conditional code has the same format
    [left | rst] = Regex.split(~r/ contains /, cell.test_clause)
    # The left is guaranteed to be a var.
    left_var = extract_vars(left)
    to_check_string = replace_var(left, left_var, env.vars)
    right = List.to_string(rst)
    right_var = extract_vars(right)
    target = replace_var(right, right_var, env.vars)

    if String.contains?(to_check_string, target) do
      traverse_graph(then_v, graph, env)
    else
      traverse_graph(else_v, graph, env)
    end
  end

  # Returns the out vertex that matches the edge label.
  defp find_out_vertex(graph, vertex, label) do
    out_edges = Graph.out_edges(graph, vertex)
    edge = Enum.find(out_edges, fn edge -> edge.label == label end)
    if edge != nil do
      edge.v2
    else
      nil
    end
  end

  # run_cell_commands is responsible interpretating commands and variables.
  # It is the most fundamental evaluation of a cell.
  ########
  # This method now returns a string... Need another case for JSON
  defp run_cell_commands(cell, env) do
    env = Map.update!(env, :vars, fn old_vars -> Map.merge(old_vars, cell.vars) end)
    # First, try replace variables and generate replaced commands
    replaced_commands = replace_vars(cell.commands, env.vars)
    # Using double for loop to run all commands on all nodes.
    try do
      results =
        Enum.map(cell.targets, fn
          each_node ->
            each_node = if is_bitstring(each_node), do: String.to_atom(each_node), else: each_node
            maped_result = Enum.map(replaced_commands, fn
              each_command ->
                IO.inspect(each_command)
                command_result =
                if String.starts_with?(each_command, "cd") do
                  directory_string = String.slice(each_command, 3..String.length(each_command))
                  Experimentwizard.Executer.change_working_directory(each_node, directory_string)
                  []
                else
                  if !cell.synchronous do
                    # Maybe use task to enable concurrency?
                    # Then sequential execution is not guaranteed...
                    Experimentwizard.Executer.run_async_command(each_node, each_command)
                  else
                    Experimentwizard.Executer.run_sync_command(each_node, each_command)
                  end
                end
            end)
            # |> List.foldl("", fn x, acc -> acc <> x end)
            # |> String.replace("\n", "")
        end)
        # |> List.foldl("", fn x, acc -> acc <> x end)

      # Return the output if needed, else discard the output.
      if cell.output do
        results |> List.flatten()
      else
        []
      end
    catch
      :exit, reason ->
        %RuntimeError{message: "abnormal exit"}
      _ ->
        %RuntimeError{message: "other exception"}
    end
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

  defp find_cell(cell_definition, env) do
    cond do
      is_list(cell_definition) ->
        cell_name = Enum.at(cell_definition, 0) |> String.to_atom()
        Map.get(env, :cells) |> Map.get(cell_name)

      is_bitstring(cell_definition) ->
        Map.get(env, :cells) |> Map.get(String.to_atom(cell_definition))

      is_struct(cell_definition) ->
        cell_definition

      true -> nil
    end
  end

  defp update_env(targets, env_to_apply) do
    Enum.map(targets, fn each_node ->
      each_node = if is_bitstring(each_node), do: String.to_atom(each_node), else: each_node
      Experimentwizard.Executer.update_env(each_node, env_to_apply)
    end)
  end
end
