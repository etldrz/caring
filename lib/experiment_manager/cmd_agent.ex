defmodule CmdAgent do
  use Agent
  require Logger

  # arbitrary definition
  @max_cmd_cost 10
  # usage is defined right now in lexer.xrl and has the values
  # low, med, high, and only 
  @low 1
  @med 3
  @high 5
  @only @max_cmd_cost

  # atoms used to indicate completed children
  @neither :none
  @child_a :a
  @child_b :b
  @completed :done

  defstruct [:type, :a, :b, :ppid, :child_pos, :completed_children]

  def start_agent(rule, parent, a_or_b, cmds \\ nil) do
    {type, a, b} =
      if is_binary(rule) do
        {rule, nil, nil}
      else
        rule
      end

    Agent.start_link(fn ->
      rule = %CmdAgent{
        type: type,
        a: a,
        b: b,
        ppid: parent,
        child_pos: a_or_b,
        completed_children: @neither
      }

      cmds =
        if is_nil(cmds) do
          GenServer.call({:global, :main}, :get_state).cmds
        else
          cmds
        end

      if is_binary(rule.type) do
        initrule(rule, cmds, :default)
      else
        initrule(rule, cmds, rule.type)
      end

      Logger.info("an agent for rule #{type} has been initialized.")
      rule
    end)
  end

  def get_available_cost(curr_cmd, same_target) do
    cond do
      curr_cmd.status === :queued ->
        Enum.reduce(same_target, @max_cmd_cost, fn c, acc ->
          acc - eval_usage_cost(c)
        end)

      curr_cmd.status != :queued ->
        raise "not implemented for status '#{curr_cmd.status}' " <>
                "with command #{curr_cmd.name}"
    end
  end

  def eval_usage_cost(cmd) do
    cond do
      cmd.usage === "low" ->
        @low

      cmd.usage === "med" ->
        @med

      cmd.usage === "high" ->
        @high

      cmd.usage === "only" ->
        @only

      is_nil(cmd.usage) ->
        0

      true ->
        raise "Bad usage value '#{cmd.usage}' found in " <>
                "command #{cmd.name}."
    end
  end

  def initrule(rule, cmds, :default) do
    which_cmd =
      Enum.find(cmds, fn c -> c.name === rule.type end)

    same_target =
      Enum.filter(cmds, fn c ->
        c.name != which_cmd.name and
          c.target === which_cmd.target and
          c.status === :running
      end)

    available_cost = get_available_cost(which_cmd, same_target)
    which_cmd_cost = eval_usage_cost(which_cmd)

    cond do
      is_nil(which_cmd.usage) ->
        # nil usage equates to zero cost
        GenServer.call({:global, which_cmd.steward}, :run)

      # steward deals with situation where it gets called to 
      # run when it is already running
      available_cost - which_cmd_cost >= 0 ->
        GenServer.call({:global, which_cmd.steward}, :run)

      available_cost - which_cmd_cost < 0 ->
        Logger.info(
          "command #{which_cmd.name} tried to run and was met with " <>
            "insufficient available resources, putting in update " <>
            "requests with running commands on the same node."
        )

        # this current command will be alerted when a steward on 
        # the same node as which_cmd finishes, it will have a new
        # chance to decide whether or not the command can be
        # run
        Enum.each(same_target, fn c ->
          GenServer.cast({:global, c.steward}, {:update_agent, self()})
        end)
    end

    rule
  end

  def initrule(rule, cmds, :then) do
    start_agent(rule.a, self(), @child_a, cmds)
  end

  def initrule(rule, cmds, :either) do
    # todo: some sort of way to speculatively execute
  end

  def initrule(rule, cmds, :together) do
    # todo: some sort of way to speculatively execute
  end

  def finished_on_node(rule, finished_cmd, status) do
    # unless speculative execution on either/together rules
    # ends up taking this route, the only rule type that
    # puts in an update request with the steward is :default.
    # The only thing to check is then whether the steward
    # is saying the current rule is completed or one from the 
    # same node. If it's the same node, we run initrule 
    # again to check if the new command is viable
    # now that one has finished
    Logger.info(
      "#{finished_cmd.steward} has finished and alerted " <>
        "rule #{rule.type}"
    )

    if rule.type === finished_cmd.name do
      signal_done(rule, status, nil)
    else
      cmds = GenServer.call({:global, :main}, :get_state).cmds
      initrule(rule, cmds, :default)
    end

    rule
  end

  def signal_done(rule, :ok, a_or_b) do
    signal_done_callback =
      if is_pid(rule.ppid) do
        fn ->
          Agent.cast(
            rule.ppid,
            fn state ->
              signal_done(state, :ok, rule.child_pos)
            end
          )
        end
      else
        fn ->
          GenServer.cast({:global, :main}, :rule_done)
        end
      end

    case rule.type do
      :then ->
        case a_or_b do
          :a ->
            start_agent(rule.b, self(), @child_b)
            %{rule | completed_children: @child_a}

          :b ->
            signal_done_callback.()
            # Agent.cast(rule.ppid, signal_done_callback)
            %{rule | completed_children: @completed}
        end

      :together ->
        case a_or_b do
          :a ->
            case rule.completed_children do
              @neither ->
                %{rule | completed_children: @child_a}

              @child_b ->
                signal_done_callback.()
                # Agent.cast(rule.ppid, signal_done_callback)
                %{rule | completed_children: @completed}

              _ ->
                raise "Undefined behavior with completed child type " <>
                        "'#{rule.completed_children}'"
            end

          :b ->
            case rule.completed_children do
              @neither ->
                %{rule | completed_children: @child_b}

              @child_a ->
                signal_done_callback.()
                # Agent.cast(rule.ppid, signal_done_callback)

                %{rule | completed_children: @completed}

              _ ->
                raise "Undefined behavior with completed child type " <>
                        "'#{rule.completed_children}'"
            end
        end

      :either ->
        signal_done_callback.()
        # Agent.cast(rule.ppid, signal_done_callback)

        case a_or_b do
          :a ->
            %{rule | completed_children: @child_a}

          :b ->
            %{rule | completed_children: @child_b}
        end

      _ ->
        signal_done_callback.()
        # Agent.cast(rule.ppid, signal_done_callback)
        %{rule | completed_children: @completed}
    end
  end

  def signal_done(state, :error, a_or_b) do
    # record in the logger, send a message to main node
  end
end
