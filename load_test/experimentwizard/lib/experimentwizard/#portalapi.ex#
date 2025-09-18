defmodule Portalapi do
  @moduledoc """
  This module provides Elixir functions to invoke PortalAPI on Emulab.
  The user may start an experiment, terminate an experiment and get
  experiment manifest using the functions provided in this module.
  """
  import SweetXml
  @server "boss.emulab.net"
  @port 3069
  @path "/usr/testbed"
  @api_version 0.1
  @recv_timeout 20_000

  @doc """
  This function returns the project that the given user belongs to.
  The 'userinfo' is a map containing the path to user's unencrypted certifile and cacertfile.
  Returns a map containing the project that given user belongs to.

  ## Examples

    iex> me = %{
    certfile: "/Users/atang/Documents/notebook-with-powder/portalapi/cloudlab-decrypted.pem",
    cacertfile: "/Users/atang/Documents/notebook-with-powder/portalapi/emulab-ca.pem"
    }

    iex> Portalapi.get_user_membership(me)
    %{"PowderSandbox" => ["PowderSandbox"]}

  """
  def get_user_membership(userinfo) do
    construct_post_query("user.membership", userinfo) |> Map.fetch!("value")
  end

  @doc """
  This function returns the number of nodes that the given user has.
  The 'userinfo' is a map containing the path to user's unencrypted certifile and cacertfile.
  Returns a map containing the number of nodes that the given user has.

  ## Examples

    iex> me = %{
    certfile: "/Users/atang/Documents/notebook-with-powder/portalapi/cloudlab-decrypted.pem",
    cacertfile: "/Users/atang/Documents/notebook-with-powder/portalapi/emulab-ca.pem"
    }

    iex> Portalapi.get_user_nodecount(me)
    1

  """
  def get_user_nodecount(userinfo) do
    construct_post_query("user.nodecount", userinfo) |> Map.fetch!("value")
  end

  @doc """
  This function returns all the experiments that the given user has.
  The 'userinfo' is a map containing the path to user's unencrypted certifile and cacertfile.
  Returns a map containing all the experiments that the given user has.

  ## Examples

    iex> me = %{
    certfile: "/Users/atang/Documents/notebook-with-powder/portalapi/cloudlab-decrypted.pem",
    cacertfile: "/Users/atang/Documents/notebook-with-powder/portalapi/emulab-ca.pem"
    }

    iex> Portalapi.get_user_experiments(me)
    %{"PowderSandbox" => %{"PowderSandbox" => ["PortalAPITesting"]}}

  """
  def get_user_experiments(userinfo) do
    construct_post_query("experiment.getlist", userinfo) |> Map.fetch!("value")
  end

  @doc """
  This function tries to start an experiment with the given name and given profile in the
  given project, if an experiment is successfully started, this function will return 0, else
  it will return error messages why the experiment couldn't be started.
  The 'userinfo' is a map containing the path to user's unencrypted certifile and cacertfile.
  The 'profile_name' is a string in the following format "name of project, name of profile"
  The 'project_name' is a string of the project where the experiment will be started in.
  The 'experiment_name' is a string of the name of the experiment.
  Returns 0 if successful, else error messages.

  ## Examples

    iex> me = %{
    certfile: "/Users/atang/Documents/notebook-with-powder/portalapi/cloudlab-decrypted.pem",
    cacertfile: "/Users/atang/Documents/notebook-with-powder/portalapi/emulab-ca.pem"
    }

    iex> Portalapi.start_experiment(me, "PowderSandbox,BandwidthSingle", "PowderSandbox", "PortalAPITesting")
    0

  """
  def start_experiment(userinfo, profile_name, project_name, experiment_name) do
    construct_post_query(
      "portal.startExperiment",
      userinfo,
      profile: profile_name,
      proj: project_name,
      name: experiment_name
    )
    |> Map.fetch!("value")
  end

  @doc """
  This function tries to terminate an experiment with the given name and given profile in the
  given project, if an experiment is successfully terminated, this function will return 0, else
  it will return error messages why the experiment couldn't be terminated.
  The 'userinfo' is a map containing the path to user's unencrypted certifile and cacertfile.
  The 'profile_name' is a string in the following format "name of project, name of profile"
  The 'project_name' is a string of the project where the experiment is in.
  The 'experiment_name' is a string of the name of the experiment.
  Returns 0 if successful, else error messages.

  ## Examples

    iex> me = %{
    certfile: "/Users/atang/Documents/notebook-with-powder/portalapi/cloudlab-decrypted.pem",
    cacertfile: "/Users/atang/Documents/notebook-with-powder/portalapi/emulab-ca.pem"
    }

    iex> Portalapi.terminate_experiment(me, "PowderSandbox,BandwidthSingle", "PowderSandbox", "PortalAPITesting")
    0

  """
  def terminate_experiment(userinfo, project_name, experiment_name) do
    construct_post_query(
      "portal.terminateExperiment",
      userinfo,
      experiment: proj_and_expt(project_name, experiment_name)
    )
    |> Map.fetch!("value")
  end

  @doc """
  This function gets the status of the given experiment in the given project.
  The 'userinfo' is a map containing the path to user's unencrypted certifile and cacertfile.
  The 'proj' is a string of the project where the experiment is in.
  The 'expt' is a string of the name of the experiment.
  Returns a map containing the status of the experiment if successful, else error messages.

  ## Examples

    iex> me = %{
    certfile: "/Users/atang/Documents/notebook-with-powder/portalapi/cloudlab-decrypted.pem",
    cacertfile: "/Users/atang/Documents/notebook-with-powder/portalapi/emulab-ca.pem"
    }

    iex> Portalapi.get_experiment_status(me, "PowderSandbox", "PortalAPITesting")
    %{
      "aggregate_status" => %{
        "urn:publicid:IDN+emulab.net+authority+cm" => %{
          "nodes" => %{},
          "status" => "provisioning"
        }
      },
      "expires" => "2023-06-02T12:19:26Z",
      "status" => "provisioning",
      "url" => "https://www.powderwireless.net/status.php?uuid=998549eb-00b9-11ee-9f39-e4434b2381fc",
      "uuid" => "998549eb-00b9-11ee-9f39-e4434b2381fc",
      "wbstore" => "99f48d84-00b9-11ee-9f39-e4434b2381fc"
    }

  """
  def get_experiment_status(userinfo, proj, expt) do
    result = construct_post_query(
      "portal.experimentStatus",
      userinfo,
      experiment: proj_and_expt(proj, expt),
      asjson: 1
    )
    if (result["code"] == 0) do
      Jason.decode!(result["output"])
    else
      result["output"]
    end
  end


  @doc """
  This function gets the manifest of the given experiment in the given project, and returns
  the simplified manifest containing the full node names, experiment IPs and control IPs.
  The 'userinfo' is a map containing the path to user's unencrypted certifile and cacertfile.
  The 'proj' is a string of the project where the experiment is in.
  The 'expt' is a string of the name of the experiment.
  Returns a list of simplified manifest if successful, else error messages.

  ## Examples

    iex> me = %{
    certfile: "/Users/atang/Documents/notebook-with-powder/portalapi/cloudlab-decrypted.pem",
    cacertfile: "/Users/atang/Documents/notebook-with-powder/portalapi/emulab-ca.pem"
    }

    iex> Portalapi.get_manifest(me, "PowderSandbox", "PortalAPITesting")
    [
      {1, 'node1.PortalAPITesting.PowderSandbox.emulab.net', '192.168.1.1',
      '155.98.38.89'},
      {2, 'node2.PortalAPITesting.PowderSandbox.emulab.net', '192.168.1.2',
      '155.98.38.118'},
      {3, 'node3.PortalAPITesting.PowderSandbox.emulab.net', '192.168.1.3',
      '155.98.38.96'}
    ]

  """
  def get_manifest(userinfo, proj, expt) do
    map = construct_post_query(
      "portal.experimentManifests",
      userinfo,
      experiment: proj_and_expt(proj, expt),
      asjson: 1
    )["output"]
    |> JSON.decode!()
    xmlstring = map["urn:publicid:IDN+emulab.net+authority+cm"]
    experiment_ips =  SweetXml.xpath(xmlstring, ~x"/rspec/node/interface/ip/@address"l)
    control_ips = SweetXml.xpath(xmlstring, ~x"/rspec/node/host/@ipv4"l)
    node_names = SweetXml.xpath(xmlstring, ~x"/rspec/node/host/@name"l)
    # Only zip non-empty lists
    # 1st element = node name
    # 2nd element = control ip address
    # 3rd element = experiment ip address
    if Enum.any?(experiment_ips) do
      List.zip([node_names, control_ips, experiment_ips])
    else
      List.zip([node_names, control_ips])
    end
  end


  @doc """
  This function checks if the experiment is ready to use and returns a simplified manifest if
  it is ready. Else the function will block untill the experiment is ready.
  The 'userinfo' is a map containing the path to user's unencrypted certifile and cacertfile.
  The 'proj' is a string of the project where the experiment is in.
  The 'expt' is a string of the name of the experiment.
  Returns a list of simplified manifest if the experiment is ready.

  ## Examples

    iex> me = %{
    certfile: "/Users/atang/Documents/notebook-with-powder/portalapi/cloudlab-decrypted.pem",
    cacertfile: "/Users/atang/Documents/notebook-with-powder/portalapi/emulab-ca.pem"
    }

    iex> Portalapi.is_experiment_ready(me, "PowderSandbox", "PortalAPITesting")
    "Experiment is not ready, keep waiting."

  """
  def is_experiment_ready(userinfo, proj, expt) do
    Process.sleep(10000)
    result = get_experiment_status(userinfo, proj, expt)["status"]
    cond do
      result == "ready" ->
        get_manifest(userinfo, proj, expt)
      result == "failed" ->
        IO.puts("Experiment instantiation failed")
      true ->
        IO.puts("Experiment is not ready, keep waiting.")
        is_experiment_ready(userinfo, proj, expt)
    end
  end

  ########## PRIVATE HELPER FUNCTIONS ##########
  defp url, do: "https://" <> @server <> ":" <> to_string(@port) <> @path

  defp proj_and_expt(proj, expt), do: proj <> "," <> expt

  defp encode_method_call(name, opts) do
    %XMLRPC.MethodCall{
      method_name: name,
      params: [@api_version, Map.new(opts)]
    }
    |> XMLRPC.encode!()
  end

  defp construct_post_query(name, userinfo, opts \\ []) do
    case HTTPoison.post(url(),
    encode_method_call(name, opts),
    [],
    [
      hackney: [pool: :default],
      ssl: [
        certfile: userinfo.certfile,
        cacertfile: userinfo.cacertfile
      ],
      recv_timeout: @recv_timeout
    ])
    do
      {:ok, response} ->
        XMLRPC.decode!(response.body).param
      {:error, reason} ->
        IO.inspect(reason)
    end
  end

end
