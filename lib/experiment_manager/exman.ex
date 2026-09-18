defmodule ExMan do
  defmacro markdown_path() do
    [h | _] = __CALLER__.file |> String.split("#")
    h
  end

  def markdown_path_fun(caller_env) do
    [h | _] = caller_env.file |> String.split("#")
    h
  end

  def regex_fetch(file) do
    reg =
      if Regex.match?(
           ~r/<!-- livebook:{"force_markdown":true} -->/,
           file
         ) do
        ~r/## RULES\s+<!-- livebook:{"force_markdown":true} -->\s+```(?:elixir|erlang|python)\s+([\s\S]*?)(?=```)/
      else
        ~r/## RULES\s+([\s\S]*?)(?=\z|## END RULES|```(?:elixir|erlang|python))/
      end

    Regex.run(reg, file)
  end

  def loadrules(caller_env) do
    # get all characters between the section 'RULES' and either
    # EOF, the section 'END RULES', or the start of a code cell
    file = markdown_path_fun(caller_env) |> File.read!()

    # does not allow for rules to be defined in more than one area
    case regex_fetch(file) do
      [_ | rules] ->
        {:ok, ls, _} =
          rules
          |> List.first()
          |> String.to_charlist()
          |> :lexer.string()

		{:ok, parsed} = :parser.parse(ls)

				CmdGraph.build_cmds(parsed)
			nil ->
        parserules(:bad_match)
    end
  end

  def parserules(:bad_match) do
    IO.puts(
      "No match on rules in the Livebook.\n" <>
        "Rules must be specified in a markdown cell \n" <>
        "and preceeded by a section entitled 'RULES'"
    )

    :no_rules_loaded
  end

  def parserules(rlist) do
  end
end
