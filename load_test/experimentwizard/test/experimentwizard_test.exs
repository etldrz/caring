defmodule ExperimentwizardTest do
  use ExUnit.Case
  doctest Experimentwizard

  test "Run from YAML" do
    executer1 = :"executer@node1.portalapitesting.powdersandbox.emulab.net"
    executer2 = :"executer@node2.portalapitesting.powdersandbox.emulab.net"
    yaml = "start: start_cell"
    yaml_result = Experimentwizard.Cell.parse_yaml_string(yaml)
    Experimentwizard.Cell.run_from_yaml(yaml_result)
  end
end
