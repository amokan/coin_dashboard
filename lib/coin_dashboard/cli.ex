defmodule CoinDashboard.CLI do
  @moduledoc """
  """

  @commands %{
    "q" => "Quit and close the dashboard"
  }

  def main(_args) do
    CoinDashboard.Dashboard.start_link([])

    receive_command()
  end

  defp receive_command do
    IO.gets("\n (q) quit > ")
    |> String.trim
    |> String.downcase
    |> execute_command
  end

  defp execute_command("q") do
    [
      IO.ANSI.clear(),
      IO.ANSI.home(),
    ] |> IO.write
  end

  defp execute_command("h") do
    print_help_message()

    receive_command()
  end

  defp execute_command(number) when is_number(number) do

    IO.puts "number: #{number}"

    receive_command()
  end

  defp execute_command(_unknown) do
    IO.puts("\nUnknown command.")
    print_help_message()

    receive_command()
  end

  defp print_help_message do
    IO.puts("\nThe dashboard supports following commands:\n")
    @commands
    |> Enum.map(fn({command, description}) -> IO.puts("  #{command} - #{description}") end)
  end

end
