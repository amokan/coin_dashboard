defmodule CoinDashboard.HistoricalData do
  @moduledoc """
  A wrapper around some ETS calls that retains historical data
  """

  use GenServer
  require Logger

  alias CoinDashboard.Providers.Coinmarketcap

  @ets_table_name :historical_data
  @ets_file_name "historical_data.tab"
  @persist_every 60_000
  @timeout 30_000
  @auto_update_top 35

  defstruct pending_updates: [],
            force_updates: [],
            available_currencies: [],
            always_update_top: 5,
            number_to_update: 12,
            update_every: 360_000, # 5 mins
            last_update: nil

  def start_link(_), do: GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  
  @doc """
  """
  def available_currency_list do
    GenServer.call(__MODULE__, :get_available_currencies, @timeout)
  end

  def view_state do
    GenServer.call(__MODULE__, :view_state, @timeout)
  end

  def set_for_update(id) when is_binary(id) do
    GenServer.cast(__MODULE__, {:set_for_update, id})
  end

  @doc """
  """
  def set(id, price_usd, price_btc, volume_usd) when is_binary(id) and is_list(price_usd) and is_list(price_btc) and is_list(volume_usd) do
    if :ets.insert(@ets_table_name, {{id}, price_usd, price_btc, volume_usd, current_timestamp()}) do
      {:ok}
    else
      {:error}
    end
  end
  def set(_id, _price_usd, _price_btc, _volume_usd), do: {:error}

  @doc """
  """
  def get(id) when is_binary(id) do
    case :ets.lookup(@ets_table_name, {id}) do
      [result|_] -> result
      _ -> nil
    end
  end
  def get(_id), do: nil

  def get_price_usd(id) do
    case get(id) do
      nil ->
        set_for_update(id)
        nil
      {{_id}, price_usd, _price_btc, _volume_usd, _timestamp} ->
        price_usd
    end
  end

  @doc """
  """
  def price_usd_sparkline(id) do
    id |> get_price_usd() |> format_sparkline_data() |> Enum.take(-31) |> create_sparkline()
  end

  @doc """
  """
  def to_list, do: :ets.tab2list(@ets_table_name)

  @doc """
  """
  def clear, do: :ets.delete_all_objects(@ets_table_name)

  @doc """
  """
  def key_list do
    to_list() |> Enum.map(fn {{key}, _, _, _, _} -> key end) |> Enum.sort
  end


  @doc false
  def init(state) do
    PersistentEts.new(@ets_table_name, @ets_file_name, [:set, :named_table, persist_every: @persist_every])
    Process.send(self(), :update_historical_data, [])
    Process.send_after(self(), :update_available_currencies, 1_000)

    {:ok, state}
  end

  def handle_call(:get_available_currencies, _from, %__MODULE__{ available_currencies: available_currencies } = state) do
    {:reply, available_currencies, state}
  end

  def handle_call(:view_state, _from, %__MODULE__{} = state) do
    {:reply, state, state}
  end

  def handle_cast({:set_for_update, id}, %__MODULE__{ force_updates: force_updates } = state) do
    {:noreply, %__MODULE__{ state | force_updates: [ id | force_updates ]}}
  end

  def handle_info(:update_historical_data, %__MODULE__{ pending_updates: [], force_updates: force_updates, always_update_top: always_update_top, number_to_update: number_to_update } = state) when is_list(force_updates) do
    {:ok, ticker_data} = Coinmarketcap.fetch_ticker(@auto_update_top)

    top_ten_ids = ticker_data |> Enum.take(always_update_top) |> Enum.map(&(&1["id"]))
    remaining_count = @auto_update_top - always_update_top

    remaining_ids = ticker_data |> Enum.take((remaining_count * -1)) |> Enum.map(&(&1["id"])) |> Enum.take_random(number_to_update)
    remaining_ids = force_updates ++ remaining_ids # add anything that was manually forced

    pending_updates = (top_ten_ids ++ remaining_ids) |> Enum.uniq

    updated_state = %__MODULE__{ state | pending_updates: pending_updates }

    Process.send_after(self(), :update_historical_data, state.update_every)
    Process.send(self(), :update_historical_data_item, [])

    {:noreply, updated_state}
  end
  def handle_info(:update_historical_data, %__MODULE__{} = state) do
    Process.send_after(self(), :update_historical_data, 15_000)
    {:noreply, %__MODULE__{ state | force_updates: [] }}
  end

  def handle_info(:update_historical_data_item, %__MODULE__{ pending_updates: [id | pending], available_currencies: available_currencies } = state) do
    {:ok, data} = Coinmarketcap.fetch_coin_data(id)

    set(id, data["price_usd"], data["price_btc"], data["volume_usd"])

    available_currencies = [id | available_currencies] |> Enum.uniq |> Enum.sort

    Process.send_after(self(), :update_historical_data_item, 10_000)

    {:noreply, %__MODULE__{ state | pending_updates: pending, available_currencies: available_currencies, last_update: current_timestamp() }}
  end
  def handle_info(:update_historical_data_item, %__MODULE__{} = state), do: {:noreply, state}

  def handle_info(:update_available_currencies, %__MODULE__{} = state) do
    {:noreply, %__MODULE__{ state | available_currencies: key_list() }}
  end

  defp format_sparkline_data(data) when is_list(data) do
    data |> Enum.map(fn [_ts, value] -> value end) 
  end
  defp format_sparkline_data(_), do: []

  defp create_sparkline([]), do: nil
  defp create_sparkline(data) when is_list(data), do: data |> Sparkline.sparkline([bar_width: 1])
  defp create_sparkline(_), do: nil

  # get the current unix timestamp
  defp current_timestamp, do: DateTime.utc_now |> DateTime.to_unix
end
