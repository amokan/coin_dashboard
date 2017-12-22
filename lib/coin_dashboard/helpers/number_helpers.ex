defmodule CoinDashboard.Helpers.NumberHelpers do
  @moduledoc """
  Various number-related helpers
  """

  @doc """
  Try to parse a string to an integer.

  If this fails, it will return a zero.

  ## Example

        iex> CoinDashboard.Helpers.NumberHelpers.string_to_integer("24")
        24

        iex> CoinDashboard.Helpers.NumberHelpers.string_to_integer(" 3  ")
        3

        iex> CoinDashboard.Helpers.NumberHelpers.string_to_integer(nil)
        0

        iex> CoinDashboard.Helpers.NumberHelpers.string_to_integer("")
        0
  """
  def string_to_integer(nil), do: 0
  def string_to_integer(""), do: 0
  def string_to_integer(numeric_string) do
    regex_result = Regex.run(~r/\d+/iux, numeric_string)

    if regex_result do
      case regex_result |> Enum.at(0) |> Integer.parse do
        { integer, _ } -> integer
        :error -> 0
        _ -> 0
      end
    else
      0
    end
  end

   @doc """
  Try to parse a string to a float.

  If this fails, it will return a `0.0`

  ## Example

        iex> CoinDashboard.Helpers.NumberHelpers.string_to_float("24")
        24.0

        iex> CoinDashboard.Helpers.NumberHelpers.string_to_float(" 3.64  ")
        3.64

        iex> CoinDashboard.Helpers.NumberHelpers.string_to_float(nil)
        0.0

        iex> CoinDashboard.Helpers.NumberHelpers.string_to_float("")
        0.0

        iex> CoinDashboard.Helpers.NumberHelpers.string_to_float("0.05800")
        0.05800

        iex> CoinDashboard.Helpers.NumberHelpers.string_to_float(".348")
        0.348

        iex> CoinDashboard.Helpers.NumberHelpers.string_to_float("-.491")
        -0.491

        iex> CoinDashboard.Helpers.NumberHelpers.string_to_float("-12.374")
        -12.374
  """
  def string_to_float(nil), do: 0.0
  def string_to_float(""), do: 0.0
  def string_to_float(numeric_string) do
    numeric_string =
      numeric_string
      |> String.trim
      |> String.codepoints
      |> fix_float_string

    regex_result = Regex.run(~r/[-+]?[0-9]*\.?[0-9]+/iux, numeric_string)

    if regex_result do
      case regex_result |> Enum.at(0) |> Float.parse do
        { integer, _ } -> integer
        :error -> 0.0
        _ -> 0.0
      end
    else
      0.0
    end
  end

  defp fix_float_string(["." | _] = numeric_string) do
    ["0" | numeric_string] |> List.to_string
  end
  defp fix_float_string(["-", "." | _] = numeric_string) do
    numeric_string |> List.insert_at(1, "0") |> List.to_string
  end
  defp fix_float_string(numeric_string), do: numeric_string |> List.to_string


  @doc """
  Attempts to convert a float to a percentage.

  ## Example

        iex> CoinDashboard.Helpers.NumberHelpers.float_to_percent(0.00058)
        0.06

        iex> CoinDashboard.Helpers.NumberHelpers.float_to_percent(nil)
        0.0

        iex> CoinDashboard.Helpers.NumberHelpers.float_to_percent(0.08394)
        8.39
  """
  def float_to_percent(nil), do: 0.0
  def float_to_percent(0), do: 0.0
  def float_to_percent(float_value) do
    float_value * 100 |> Float.round(2)
  end

end
