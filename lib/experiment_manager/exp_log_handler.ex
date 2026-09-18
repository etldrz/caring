defmodule ExpLog do

  require :logger_handler

  def log(event, config) do
    case event[:level] do
      :info ->
	handle_info(event, config)
      :warning ->
	handle_warning(event, config)
      :debug ->
	handle_debug(event, config)
      :error ->
	handle_error(event, config)
      _ ->
	""
    end
  end

  defp handle_info(event, config) do
    # send log events to logpool
    # potentially in mainnode, give
    # options for displaying
    IO.inspect(event[:msg])
  end

  defp handle_warning(event, config) do
  end

  defp handle_debug(event, config) do
  end

  defp handle_error(event, config) do
  end
  
end
