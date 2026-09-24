defmodule CmdGraph do
  defmodule Cmd do
    defstruct [:name, :body, :usage, :target, status: :queued]
  end

  def build_cmds(parsed) do
    {cmds, rules} =
      Enum.split_with(parsed, fn x ->
        case x do
          {:defcmd, _} ->
            true

          _ ->
            false
        end
      end)

    cmds =
      cmds
      |> Enum.map(fn x ->
        case x do
          {:defcmd, {{:id, _, name}, {:body, _, body}, {:id, _, target}}} ->
            %Cmd{name: List.to_string(name), body: body, target: target}

          {:defcmd, {{:id, _, name}, {:body, _, body}, {:usage, _, usage}, {:id, _, target}}} ->
            %Cmd{name: List.to_string(name), body: body, usage: usage, target: target}

          _ ->
            raise "Inappropriate cmd value\n#{inspect(x)}"
        end
      end)

    cmd_set_defs = MapSet.new(cmds, fn c -> c.name end)

    cmd_set_rules =
      Enum.reduce(rules, [], fn r, acc ->
        retrieve_cmds(r, acc)
      end)
      |> MapSet.new()

    defs_but_not_rules = MapSet.difference(cmd_set_defs, cmd_set_rules)
    rules_but_not_defs = MapSet.difference(cmd_set_rules, cmd_set_defs)

    cond do
      MapSet.size(defs_but_not_rules) > 0 ->
        raise "There are commands defined that are not used in rules: 
        #{Enum.join(defs_but_not_rules, ", ")}"

      MapSet.size(rules_but_not_defs) > 0 ->
        raise "There are named commands used in the ruleset that are not defined prior: 
        #{Enum.join(rules_but_not_defs, ", ")}"
    end

    IO.inspect(cmds, label: "commands")

    IO.inspect(rules, label: "rules")
  end

  def retrieve_cmds(rule, acc) do
    case rule do
      {_, a, b} ->
        cond do
          is_list(a) and is_list(b) ->
            [List.to_string(a) | [List.to_string(b) | acc]]

          not is_list(a) and is_list(b) ->
            [List.to_string(b) | retrieve_cmds(a, acc)]

          is_list(a) and not is_list(b) ->
            [List.to_string(a) | retrieve_cmds(b, acc)]

          not is_list(a) and not is_list(b) ->
            acc = retrieve_cmds(a, acc)
            retrieve_cmds(b, acc)
        end

      a when is_list(a) ->
        [List.to_string(a) | acc]

      a ->
        raise "Improper format #{inspect(a)}"
    end
  end
end
