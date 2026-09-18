defmodule ExperimentManagerTest do
  use ExUnit.Case
  doctest ExperimentManager

  test "greets the world" do
    assert ExperimentManager.hello() == :world
  end
end
