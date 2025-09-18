defmodule Experimentwizard.RuntimeManager do
  # Let env = %{
  #  vars: %{},
  #  results: %{},
  #  graph: %{},
  #  pre_breakpoints: MapSet.new(),
  #  post_breakpoints: MapSet.new(),
  #  error_count: 0,
  #  next_vertex: nil
  # }

  # 1. A super node stores a graph containing all the necessary procedural cells
  # 2. Procedural cells in a graph can only refer to a super node or other cells within the same node.
  # 3. If a procedural cell does not have any out neighbors that means it is the end of the execution for a part.

  def add_pre_breakpoint(env, cell_name) do
    Map.update!(env, :pre_breakpoints, fn old -> MapSet.put(old, cell_name) end)
  end

  def add_post_breakpoint(env, cell_name) do
    Map.update!(env, :post_breakpoints, fn old -> MapSet.put(old, cell_name) end)
  end

  def parse_yaml_string(string) do
    {code, result} = YamlElixir.read_from_string(string)

    if code == :ok do
      # Now parse the results
      Enum.map(result, fn each_definition -> parse_definition(each_definition) end)
      |> Map.new()
    else
      IO.inspect(result)
    end
  end

  def parse_yaml_file(path) do
    {code, result} = YamlElixir.read_from_file(path)

    if code == :ok do
      # Now parse the results
      Enum.map(result, fn each_definition -> parse_definition(each_definition) end)
    else
      IO.inspect(result)
    end
  end

  def run_from_yaml(yaml_results, half_env \\ %{}) do
    {graph, first_v} =
      construct_graph_from_yaml(yaml_results.requires, yaml_results.is, yaml_results.cells)

    env =
      Map.merge(
        %{
          vars: %{},
          results: %{},
          pre_breakpoints: MapSet.new(),
          post_breakpoints: MapSet.new(),
          next_vertex: nil,
          error_count: 0
        },
        yaml_results
      )

    env = Map.merge(env, half_env)

    Experimentwizard.Cell.traverse_graph(first_v, graph, env)
  end

  # Grammar for YAML
  ######## YAML ########
  # is: evaluation_pattern
  # requires:
  #   start: start_cell (For simple evaluation pattern)
  #   #### or ####
  #   client: client_cell
  #   server: server_cell
  # cells:
  #   cell1, cell2, ...
  # Given an evaluation pattern, required cells, and cell_list, return the list of cells.
  def construct_cells_list(cell_list, evaluation_pattern, cells_collection) do
    cond do
      evaluation_pattern == "client-server" ->
        # Can assume cell_list is a map.
        # Run the server_setup -> client_setup ->
        # server_command -> client_command ->
        # client_teardown -> server_teardown

        # Need to think about the pattern of fault recovery.
        # If the server fail, first run the setup of the server and the commands and then the teardown.
        # Same for the client.

        # When recovering from fault, first
        client_cell_name = Map.get(cell_list, "client")
        server_cell_name = Map.get(cell_list, "server")
        client_cell = convert_and_find(client_cell_name, cells_collection)
        server_cell = convert_and_find(server_cell_name, cells_collection)

        list =
          generate_cell_list([], server_cell.setup, cells_collection)
          |> generate_cell_list(client_cell.setup, cells_collection)

        list = list ++ [server_cell_name, client_cell_name]

        generate_cell_list(list, client_cell.teardown, cells_collection)
        |> generate_cell_list(server_cell.teardown, cells_collection)

      # In the simple evaluation pattern, there's no branch so it would just be a straight line.
      evaluation_pattern == "simple" ->
        start_cell_name = Map.get(cell_list, "start")
        generate_cell_list([], start_cell_name, cells_collection)

      true ->
        "true"
    end
  end

  ### Let the grammar be
  ### Client:
  ###   setup: must be a set of cells
  ###   doit: must be a set of cells
  ###   teardown: must be a set of cells
  ### Server:
  ###   setup: must be a set of cells
  ###   doit: must be a set of cells
  ###   teardown: must be a set of cells

  def construct_graph_from_yaml(cell_list, evaluation_pattern, cells_collection) do
    g = Graph.new()

    cond do
      evaluation_pattern == "client-server" ->
        server_setup = Map.get(cell_list, "server_setup")
        client_setup = Map.get(cell_list, "client_setup")
        client = Map.get(cell_list, "client")
        server = Map.get(cell_list, "server")
        server_teardown = Map.get(cell_list, "server_teardown")
        client_teardown = Map.get(cell_list, "client_teardown")

        generate_graph({g, nil}, server_setup, "server_setup", "server", cells_collection)
        |> generate_graph(server, "server", "client_setup", cells_collection)
        |> generate_graph(client_setup, "client_setup", "client", cells_collection)
        |> generate_graph(client, "client", "client_teardown", cells_collection)
        |> generate_graph(client_teardown, "client_teardown", "server_teardown", cells_collection)
        |> generate_graph(server_teardown, "server_teardown", "terminate", cells_collection)


      # The fault recovery defined by the YAML file should override default.
      evaluation_pattern == "simple" ->
        entry_point = Map.get(cell_list, "start")
        generate_graph({g, nil}, entry_point, "start_anchor", "terminate", cells_collection)
      true ->
        "true"
    end
  end



  # This returns
  defp generate_graph(graph_firstv_tuple, entry_point, anchor, next_anchor, cells_collection) do
    {graph, first_v} = graph_firstv_tuple
    if entry_point != nil do
      {subgraph, endpoints, sub_first_v} = create_subgraph(graph, anchor, entry_point, cells_collection)
      updated_graph = connect_subgraph({subgraph, endpoints}, next_anchor)
      # First vertex is only updated once
      if first_v == nil do
        {updated_graph, sub_first_v}
      else
        {updated_graph, first_v}
      end
    else
      {connect_subgraph({graph, [anchor]}, next_anchor), first_v}
    end
  end

  # This method returns a graph
  defp connect_subgraph(graph_endpoints_tuple, next_anchor) do
    {updated_graph, endpoints} = graph_endpoints_tuple
    if next_anchor != nil do
      List.foldl(endpoints, updated_graph, fn x, acc -> Graph.add_edge(acc, x, next_anchor, label: :next) end)
    else
      updated_graph
    end
  end

  # Method for graph-based representation.
  # Given a cell, add its current, next, and previous tasks to the graph
  # as vertices and connect those vertices in the corresponding order.

  # This method prepends an anchor and starts building a graph
  # Returns a updated sub_graph and endpoints
  defp create_subgraph(sub_graph, default_anchor, entry_point, cells_collection) do
    state = get_order_from_cell(%{graph: sub_graph, order: [], anchor: default_anchor, cells_collection: cells_collection, end_points: []}, entry_point)
    order = state[:order]
    first_vertex = List.first(order)
    endpoints = state[:end_points] ++ [List.last(order)]
    # IO.puts("order: ")
    # IO.inspect(order)
    # IO.inspect(default_anchor)
    {create_subgraph_from_list(order, state[:graph], default_anchor), endpoints, first_vertex}
  end

  # This function returns the state which contains a graph and an order list.
  # 1. the graph
  # 2. order_list
  # 3. fault-recovery anchor
  # 4. cells_collection
  # 5. end_vertices, a list of vertices indicating potential end points of the workflow.
  defp get_order_from_cell(state, cell_name) do
    graph = Map.get(state, :graph)
    anchor = Map.get(state, :anchor)
    end_points = Map.get(state, :end_points)
    cells_collection = Map.get(state, :cells_collection)

    if cell_name != nil do
      cell = convert_and_find(cell_name, cells_collection)

      # Mutate the state
      state =
        if cell.on_error != nil do
          Map.replace!(state, :graph, Graph.add_edge(graph, cell_name, cell.on_error, label: :on_error))
        else
          Map.replace!(state, :graph, Graph.add_edge(graph, cell_name, anchor, label: :on_error))
        end

      # Now for the conditional nodes
      # Treat conditional node as a node that is guaranteed to not have any setup or teardown
      # So at the end of modifying the graph it should just append to the list.
      state = if cell.is_conditional do
        new_state = %{graph: graph, order: [], anchor: anchor, cells_collection: cells_collection, end_points: end_points}

        thn_state = get_order_from_cell(new_state, cell.thn_cell)
        thn_order_list = thn_state[:order]
        modified_graph = thn_state[:graph]
        thn_graph = create_subgraph_from_list(thn_order_list, modified_graph, nil)

        els_state = Map.replace!(new_state, :graph, thn_graph) |> get_order_from_cell(cell.els_cell)
        els_order_list = els_state[:order]
        modified_graph = els_state[:graph]
        els_graph = create_subgraph_from_list(els_order_list, modified_graph, nil)

        thn_end = List.last(thn_order_list)
        els_end = List.last(els_order_list)
        # Now add the thn and els edges to the graph.
        graph = els_graph |> Graph.add_edge(cell_name, Enum.at(thn_order_list, 0), label: :then_v)
        |> Graph.add_edge(cell_name, Enum.at(els_order_list, 0), label: :else_v)

        # Finally mutate the state by adding this node to the order and changing the graph
        Map.update!(state, :order, fn x -> x ++ [cell_name] end)
        |> Map.replace!(:graph, graph)
        |> Map.update!(:end_points, fn x -> x ++ [thn_end, els_end] end)
      else
        # In-order traversal of the tree
        get_order_from_cell(state, cell.setup)
        |> Map.update!(:order, fn x -> x ++ [cell_name] end)
        |> get_order_from_cell(cell.teardown)
      end
    else
      state
    end
  end

    # This function creates a subgraph from a list by adding an edge between each node in the list.
  defp create_subgraph_from_list(order_list, graph, prev_node) do
    [fst | rst] = order_list
    if Enum.any?(rst) do
      graph = if prev_node != nil do
        Graph.add_edge(graph, prev_node, fst, label: :next)
      end
      create_subgraph_from_list(rst, graph, fst)
    else
      if prev_node != nil do
        Graph.add_edge(graph, prev_node, fst, label: :next)
      else
        graph
      end
    end
  end

  # Assume cell_name is a string
  defp convert_and_find(cell_name, all_cells) do
    Map.get(all_cells, String.to_atom(cell_name))
  end

  defp generate_cell_list(current_list, cell_name, cells_collection) do
    if cell_name != nil do
      cell = convert_and_find(cell_name, cells_collection)
      cond do
        cell.setup == nil && cell.teardown == nil ->
          current_list ++ [cell_name]

        cell.setup == nil && cell.teardown != nil ->
          current_list = current_list ++ [cell_name]
          generate_cell_list(current_list, cell.teardown, cells_collection)

        cell.setup != nil && cell.teardown == nil ->
          current_list = generate_cell_list(current_list, cell.setup, cells_collection)
          current_list ++ [cell_name]

        true ->
          current_list = generate_cell_list(current_list, cell.setup, cells_collection)
          current_list = current_list ++ [cell_name]
          current_list ++ generate_cell_list(current_list, cell.teardown, cells_collection)
      end
    else
      current_list
    end
  end

  defp parse_definition(def_map) do
    # Each definition will be a tuple, the first element is the definition name, the second element will be the content.
    field_name = elem(def_map, 0)

    cond do
      field_name == "cells" ->
        # The definition of all cells will be a map
        cells_map =
          Enum.map(elem(def_map, 1), fn {k, v} -> create_cell_from_def(k, v) end)
          |> List.flatten()
          |> Map.new()

        {:cells, cells_map}

      field_name == "start" ->
        {:start, elem(def_map, 1)}

      field_name == "is" ->
        {:is, elem(def_map, 1)}

      field_name == "requires" ->
        {:requires, elem(def_map, 1)}

      String.starts_with?(field_name, "env") ->
        {String.to_atom(field_name), elem(def_map, 1)}

      true ->
        def_map
    end
  end

  defp create_cell_from_def(cell_name, definitions) do
    cell =
      %Experimentwizard.Cell{}
      |> Experimentwizard.Cell.name(cell_name)
      # Convert the keys of the definitions into atoms so that it could be merged.
      |> Map.merge(for {k, v} <- definitions, into: %{}, do: {String.to_atom(k), v})

    {String.to_atom(cell_name), cell}
  end

end
