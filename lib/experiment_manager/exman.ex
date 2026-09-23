defmodule ExMan do

  def loadrules(rulestr) do
    {:ok, ls, _} =
      rulestr
      |> String.to_charlist()
      |> :lexer.string()

    {:ok, parsed} = :parser.parse(ls)
    CmdGraph.build_cmds(parsed)
  end

end
