defmodule CmdGraph do
  defmodule Cmd do
    defstruct [:name, :body, :usage, :target]
  end

  def build_cmds(parsed) do
    {cmds, rules} =
      Enum.split_with(parsed, fn x ->
        case x do
          [:defcmd, _] ->
            true

          _ ->
            false
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

          _ ->
            raise "Inappropriate cmd value\n#{inspect(x)}"
        end
      end)

    cmd_set_defs = MapSet.new(cmds, fn c -> c[:name] end)
    cmd_set_rules = retrieve_cmds(rules)
    defs_but_not_rules = MapSet.difference(cmd_set_defs, cmd_set_rules)
    rules_but_not_defs = MapSet.difference(cmd_set_rules, cmd_set_defs)

    cond do
      defs_but_not_rules.size > 0 ->
        raise "There are commands defined that are not used in rules: #{inspect(defs_but_not_rules)}"

      rules_but_not_defs.size > 0 ->
        raise "There are named commands used in the ruleset that are not defined prior: #{inspect(rules_but_not_defs)}"
    end

    IO.inspect(cmds, label: "commands")

    IO.inspect(rules, label: "rules")
  end

  def retrieve_cmds(rules) do
    Enum.reduce(rules, MapSet.new(), fn r, acc ->
      case r do
        {_, a, b} ->
          cond do
            is_list(a) and is_list(b) ->
              acc.put(a) |> acc.put(b)

            not is_list(a) and is_list(b) ->
              acc.put(retrieve_cmds(a)) |> acc.put(b)

            is_list(a) and not is_list(b) ->
              acc.put(a) |> acc.put(retrieve_cmds(b))

            not is_list(a) and not is_list(b) ->
              acc.put(retrieve_cmds(a)) |> acc.put(retrieve_cmds(b))
          end

        a when is_list(a) ->
          acc.put(a)

        _ ->
          raise "retrieve_cmds: improper format"
      end
    end)
  end
end
