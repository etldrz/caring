defmodule LogAndRunTest do
  use ExUnit.Case
  doctest LogAndRun

  test "greets the world" do
    assert LogAndRun.hello() == :world
  end
end
