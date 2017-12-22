defmodule CoinDashboard.Dashboard do
  @moduledoc """
  """

  use Timex
  use GenServer

  alias CoinDashboard.Providers.Coinmarketcap
  alias TableRex.{Cell, Table}
  alias CoinDashboard.Helpers.NumberHelpers

  defstruct current_data: [],
            previous_price_data: [],
            last_update: nil,
            limit_top: 25,
            auto_update: true,
            auto_render: true,
            render_every: 30_000,
            update_every: 180_000 # update every 1.5 mins


  @doc """
  """
  def start_link(_), do: GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)

  def render!, do: GenServer.call(__MODULE__, :render_now)
  def update!, do: GenServer.call(__MODULE__, :update_now)

  def auto_render_on, do: GenServer.call(__MODULE__, {:set_auto_render, true})
  def auto_render_off, do: GenServer.call(__MODULE__, {:set_auto_render, false})

  def auto_update_on, do: GenServer.call(__MODULE__, {:set_auto_update, true})
  def auto_update_off, do: GenServer.call(__MODULE__, {:set_auto_update, false})

  @doc false
  def init(%__MODULE__{} = state) do
    Process.send(self(), :update_data, [])
    Process.send(self(), :render_dashboard, [])
    
    {:ok, state}
  end

  def handle_call(:render_now, _from, %__MODULE__{current_data: []} = state) do
    

    Process.send(self(), :update_data, [])
    Process.send(self(), :render_dashboard, [])

    {:reply, :ok, state}
  end
  def handle_call(:render_now, _from, %__MODULE__{} = state) do
    Process.send(self(), :render_dashboard, [])

    {:reply, :ok, state}
  end

  def handle_call(:update_now, _from, %__MODULE__{} = state) do
    Process.send(self(), :update_data, [])
    Process.send(self(), :render_dashboard, [])

    {:reply, :ok, state}
  end

  def handle_call({:set_auto_render, true}, _from, %__MODULE__{ auto_render: false } = state) do
    Process.send(self(), :render_dashboard, [])
    {:reply, :ok, %__MODULE__{ state | auto_render: true }}
  end
  def handle_call({:set_auto_render, true}, _from, %__MODULE__{} = state), do: {:reply, :ok, state}
  def handle_call({:set_auto_render, false}, _from, %__MODULE__{} = state) do
    {:reply, :ok, %__MODULE__{ state | auto_render: false }}
  end

  def handle_call({:set_auto_update, true}, _from, %__MODULE__{ auto_update: false } = state) do
    Process.send(self(), :update_data, [])
    Process.send(self(), :render_dashboard, [])
    {:reply, :ok, %__MODULE__{ state | auto_update: true }}
  end
  def handle_call({:set_auto_update, true}, _from, %__MODULE__{} = state), do: {:reply, :ok, state}
  def handle_call({:set_auto_update, false}, _from, %__MODULE__{} = state) do
    {:reply, :ok, %__MODULE__{ state | auto_update: false }}
  end

  #
  def handle_info(:render_dashboard, %__MODULE__{ current_data: current_data, render_every: render_every, last_update: last_update, previous_price_data: previous_price_data, limit_top: limit_top } = state) do
    title = "CoinMarketCap - #{current_date_string()} (#{last_update_formatted(last_update)})"
    header = ["Rank", "Name", "Ticker", "Market Cap", "Price", "% (1h)", "% (24h)", "% (7d)", "Chart"]

    rows =
      current_data
      |> Enum.map(&([&1["rank"], &1["id"], &1["name"], &1["symbol"], &1["market_cap_usd"], &1["price_usd"], &1["percent_change_1h"], &1["percent_change_24h"], &1["percent_change_7d"]]))
      |> process_rows(previous_price_data)
      |> Enum.take(limit_top)

    table =
      Table.new(rows, header, title)
      |> Table.put_header_meta(0..100, color: IO.ANSI.blue)
      |> Table.render!(horizontal_style: :all)

    # write to the terminal
    [IO.ANSI.clear, IO.ANSI.home, table] |> IO.write

    if state.auto_render, do: Process.send_after(self(), :render_dashboard, render_every)
    
    {:noreply, state}
  end

  #
  def handle_info(:update_data, %__MODULE__{ auto_update: auto_update, limit_top: limit_top } = state) do
    updated_state = state |> set_previous_price_data()

    limit = limit_top + 5

    updated_state =
      case Coinmarketcap.fetch_ticker(limit) do
        {:ok, ticker_data} -> %__MODULE__{ updated_state | current_data: ticker_data, last_update: current_timestamp() }
        _ -> %__MODULE__{ updated_state | current_data: [] }
      end

    # schedule for the next update if `auto_update` is enabled
    if auto_update, do: Process.send_after(self(), :update_data, state.update_every)

    {:noreply, updated_state}
  end

  defp set_previous_price_data(%__MODULE__{ current_data: [] } = state), do: %__MODULE__{ state | previous_price_data: [] }
  defp set_previous_price_data(%__MODULE__{ current_data: current_data } = state) do
    price_data =
      current_data
      |> Enum.map(&({String.to_atom(&1["symbol"]), NumberHelpers.string_to_float(&1["price_usd"])}))

    %__MODULE__{ state | previous_price_data: price_data }
  end

  defp current_date_string do
    Timex.local |> Timex.format!("%A, %B %e %l:%M%P", :strftime)
  end

  defp last_update_formatted(timestamp) do
    with d <- timestamp |> Duration.from_seconds(),
         diff <- Duration.diff(d, Duration.now),
         humanized_string <- diff |> Timex.format_duration(:humanized),
         do: "data refreshed #{humanized_string} ago"
  end

  defp process_rows(rows, previous_price_data), do: process_rows(rows, previous_price_data, [])
  defp process_rows([], _previous_price_data, output), do: output |> Enum.reverse()
  defp process_rows([row | rows], previous_price_data, output) do
    process_rows(rows, previous_price_data, [process_row(row, previous_price_data) | output])
  end

  defp process_row([rank, id, name, symbol, market_cap_usd, price_usd, percent_change_1h, percent_change_24h, percent_change_7d], previous_price_data) do
    with market_cap_usd <- market_cap_usd |> NumberHelpers.string_to_float |> Number.Delimit.number_to_delimited([precision: 0]),
         price_usd_float <- price_usd |> NumberHelpers.string_to_float,
         {price_usd, _price_color} <- format_price_display(symbol, price_usd_float, previous_price_data),
         percent_change_1h_raw <- percent_change_1h |> NumberHelpers.string_to_float,
         percent_change_24h_raw <- percent_change_24h |> NumberHelpers.string_to_float,
         percent_change_7d_raw <- percent_change_7d |> NumberHelpers.string_to_float,
         percent_change_1h <- percent_change_1h_raw |> Number.Percentage.number_to_percentage,
         percent_change_24h <- percent_change_24h_raw |> Number.Percentage.number_to_percentage,
         percent_change_7d <- percent_change_7d_raw |> Number.Percentage.number_to_percentage,
         sparkline_chart <- CoinDashboard.HistoricalData.price_usd_sparkline(id),
         percent_change_1h_color <- percent_change_1h_raw |> set_row_color(),
         percent_change_24h_color <- percent_change_24h_raw |> set_row_color(),
         percent_change_7d_color <- percent_change_7d_raw |> set_row_color(),
         do: [rank, name, symbol, market_cap_usd, price_usd, %Cell{value: percent_change_1h, color: percent_change_1h_color}, %Cell{value: percent_change_24h, color: percent_change_24h_color}, %Cell{value: percent_change_7d, color: percent_change_7d_color}, sparkline_chart]
  end

  defp format_price_display(symbol, price, previous_price_data) do
    current_price_string = price |> Number.Currency.number_to_currency

    case price_indicator(symbol, price, previous_price_data) do
      "" -> {current_price_string, IO.ANSI.default_color}
      {arrow, color} -> {"#{current_price_string} #{arrow}", color}
    end
  end

  defp price_indicator(_symbol, _current_price, []), do: ""
  defp price_indicator(symbol, current_price, previous_price_data) when is_binary(symbol) and is_list(previous_price_data) do
    symbol |> String.to_atom |> price_indicator(current_price, previous_price_data)
  end
  defp price_indicator(symbol, current_price, previous_price_data) when is_atom(symbol) and is_list(previous_price_data) do
    case Keyword.get(previous_price_data, symbol) do
      nil -> ""
      previous_price -> arrow(current_price, previous_price)
    end
  end
  defp price_indicator(_symbol, _current_price, _previous_price_data), do: ""

  defp arrow(current_price, previous_price) when current_price > previous_price, do: {"▲", IO.ANSI.green}
  defp arrow(current_price, previous_price) when current_price < previous_price, do: {"▼", IO.ANSI.red}
  defp arrow(_current_price, _previous_price), do: ""

  defp set_row_color(percent_change) when is_float(percent_change) and percent_change < 0.0 do
    [:red_background, :white]
  end
  defp set_row_color(percent_change) when is_float(percent_change) and percent_change > 0.0 do
    [:green_background, :black]
  end
  defp set_row_color(_percent_change), do: nil

  defp current_timestamp, do: DateTime.utc_now |> DateTime.to_unix

end
