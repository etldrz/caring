defmodule CmdAgent do
  use Agent

  def start_link({:then, a, b}, gname) do
    Agent.start_link(fn -> %{taget: a, await: b} end, name: {:global, gname})
  end

  def fulfilled?(cmd) do
    {_, await} = Agent.get(& &1)
    if a_fulfills_b(cmd, await), do: execute(cmd)
  end

  defp execute(cmd) do
  end

  defp a_fulfills_b(a, b) do
    # should only be eithers and togethers here.
    # with each b, traverse to the bottom and return 
    # true if {either, a, _} is at the bototm. else,
    # return false. for now, its just one level either that 
    # i will setup
    case b do
      {:either, l, r} ->  if a === l or a === r do
          true
      else
          false
      end
      _ -> false
    end
  end
end
