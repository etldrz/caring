defmodule CmdGraph do

  defmodule Cmd do
    defstruct [:name, :body, :usage, :target]
  end

  def build_cmds(parsed) do
    {cmds, rules} =
      Enum.split_with(parsed, fn x ->
        case x do
          [:defcmd, _] -> true
        _ -> false
      end
          end)
    cmds =
      cmds
      |> Enum.map(fn x ->
        case x do
          [:defcmd, [{:id, _, name}, {:body, _, body}, {:id, _, target}]] ->
          %Cmd{name: List.to_string(name), body: body, target: target}

          [:defcmd, [{:id, _, name}, {:body, _, body}, {:usage, _, usage}, {:id, _, target}]] ->
          %Cmd{name: List.to_string(name), body: body, usage: usage, target: target}
          _ -> raise "Inappropriate cmd value\n#{inspect(x)}"
        end
      end)

    IO.inspect(cmds, label: "commands")
    IO.inspect(rules, label: "rules")

  end

end

# defmodule Cmd do
#   defstruct [:name, :body, :usage, :target, :edges]
# end
#   def build_graph(parsed) do
#     {cmds, rules} =
#       Enum.split_with(parsed, fn x ->
#         case x do
#           {:defcmd, _} -> true
#           _ -> false
#         end
#       end)

#     cmds =
#       cmds
#       |> Enum.map(fn x ->
#         case x do
#           {:defcmd, {{:id, _, name}, {:body, _, body}, {:id, _, target}}} ->
#             %Cmd{name: name, body: body, target: target, edges: []}

#           {:defcmd, {{:id, _, name}, {:body, _, body}, {:usage, _, usage}, {:id, _, target}}} ->
#             %Cmd{name: name, body: body, usage: usage, target: target, edges: []}
#         end
#       end)

#     {_, cmds} = build_ruleset(rules, cmds)
#     cmds
#   end

#   def build_ruleset(rules, cmds) do
#     # if a node gets added without any prior pointer
#     # A then B
#     # C then B
#     # then make the head node point to C

#     rules =
#       if is_list(rules) do
#         rules
#       else
#         [rules]
#       end

#     IO.inspect(rules, label: "rules")
#     IO.inspect(cmds, label: "cmds")

#     Enum.reduce(rules, {[], cmds}, fn r, {_, cmds} ->
#       # if a/b are strings then they are command names
#       # and the edges should be set according to the command.
#       # otherwise, they are rule types and should be
#       # recursively followed for dangling nodes
#       case r do
#         {:then, a, b} ->
#           cond do
#             is_list(a) and is_list(b) ->
#               cmds = set_edge(b, [a], cmds)
#               {[b], cmds}

#             not is_list(a) and is_list(b) ->
#               {dangling_a, cmds} = build_ruleset([a], cmds)
#               cmds = set_edge(b, dangling_a, cmds)
#               {[b], cmds}

#             is_list(a) and not is_list(b) ->
#               {dangling_b, cmds} = build_ruleset([b], cmds)
#               cmds = set_edge(dangling_b, [a], cmds)
#               {dangling_b, cmds}

#             not is_list(a) and not is_list(b) ->
#               {dangling_a, cmds} = build_ruleset([a], cmds)
#               {dangling_b, cmds} = build_ruleset([b], cmds)
#               cmds = set_edge(dangling_b, dangling_a, cmds)
#               {dangling_b, cmds}
#           end

#         {:together, a, b} ->
#           cond do
#             # point a and b at eachother, then return [a, b]
#             is_list(a) and is_list(b) ->
#               cmds = set_edge(b, [a], cmds)
#               cmds = set_edge(a, [b], cmds)
#               {[a, b], cmds}

#             not is_list(a) and is_list(b) ->
#               {dangling_a, cmds} = build_ruleset(a, cmds)
#               cmds = set_edge(b, dangling_a, cmds)
#               cmds = set_edge(dangling_a, b, cmds)
#               {[b] ++ dangling_a, cmds}

#             is_list(a) and not is_list(b) ->
#               {dangling_b, cmds} = build_ruleset(b, cmds)
#               cmds = set_edge(dangling_b, [a], cmds)
#               cmds = set_edge(a, dangling_b, cmds)
#               {[a] ++ dangling_b, cmds}

#             not is_list(a) and not is_list(b) ->
#               {dangling_a, cmds} = build_ruleset(a, cmds)
#               {dangling_b, cmds} = build_ruleset(b, cmds)
#               cmds = set_edge(dangling_b, dangling_a, cmds)
#               cmds = set_edge(dangling_a, dangling_b, cmds)
#               {[dangling_b | dangling_a], cmds}
#           end

#         {:either, a, b} ->
#           # get and return dangling
#           cond do
#             is_list(a) and is_list(b) ->
#               {[a, b], cmds}

#             not is_list(a) and is_list(b) ->
#               {dangling_a, cmds} = build_ruleset(a, cmds)
#               {[b] ++ dangling_a, cmds}

#             is_list(a) and not is_list(b) ->
#               {dangling_b, cmds} = build_ruleset(b, cmds)
#               {[a] ++ dangling_b, cmds}

#             not is_list(a) and not is_list(b) ->
#               {dangling_a, cmds} = build_ruleset(a, cmds)
#               {dangling_b, cmds} = build_ruleset(b, cmds)
#               {[dangling_b | dangling_a], cmds}
#           end

#         _ ->
#           IO.puts("bad")
#           IO.inspect(r)
#       end
#     end)
#   end

#   def set_edge(edges_to_set, apply_to, cmd_list) do
#     # erlang charlist check
#     edges_to_set =
#       if List.ascii_printable?(edges_to_set) do
#         [edges_to_set]
#       else
#         edges_to_set
#       end

#     Enum.map(cmd_list, fn c ->
#       %Cmd{name: c_name, edges: c_edges} = c

#       found = Enum.find(apply_to, fn x -> x == c_name end)

#       if found do
# 		Enum.each(edges_to_set, fn x ->
#           if x == c_name do
#             raise(
#               ArgumentError, 
#               "Commands are not allowed to point towards themself: #{c_name} tries to do so\n"
#             )
# 		  end
# 		end)

#         %{c | edges: c_edges ++ edges_to_set}
#       else
#         c
#       end
#     end)
#   end
# end
