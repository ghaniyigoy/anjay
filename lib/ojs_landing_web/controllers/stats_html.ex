defmodule OjsLandingWeb.StatsHTML do
  use OjsLandingWeb, :html

  embed_templates "stats_html/*"

  @doc """
  OJS PKP 3.5 style left sidebar for the Statistics section.
  """
  attr :section, :atom, required: true
  attr :journal_path, :string, required: true

  def stats_sidebar(assigns) do
    ~H"""
    <aside class="editor-sidebar">
      <div class="sidebar-section">
        <div class="sidebar-header stats-sidebar-active">
          <svg
            class="sidebar-icon"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <line x1="18" y1="20" x2="18" y2="10"></line>
            <line x1="12" y1="20" x2="12" y2="4"></line>
            <line x1="6" y1="20" x2="6" y2="14"></line>
          </svg>
          <span class="sidebar-title">Statistics</span>
        </div>
        <ul class="sidebar-menu" style="display: block">
          <li class={stats_active(@section, :publications)}>
            <a href={"/#{@journal_path}/stats/publications/publications"}>Publications</a>
          </li>
        </ul>
      </div>
    </aside>
    """
  end

  @doc """
  OJS style breadcrumb so users can jump back to the editor dashboard.
  """
  attr :section, :string, required: true

  def stats_breadcrumb(assigns) do
    ~H"""
    <div class="settings-breadcrumb">
      <a href="/dashboard/editorial">Dashboard</a>
      <span class="settings-breadcrumb-sep">/</span>
      <span>Statistics</span>
      <span class="settings-breadcrumb-sep">/</span>
      <span>{@section}</span>
    </div>
    """
  end

  @doc """
  A lightweight CSS bar chart for a series of monthly values.
  Each point may carry `views` and `downloads` (or just `count`).
  """
  attr :series, :list, required: true
  attr :mode, :atom, default: :views, doc: ":views | :downloads | :count"

  def bar_chart(assigns) do
    max_val =
      assigns.series
      |> Enum.flat_map(fn p ->
        case assigns.mode do
          :count -> [p.count || 0]
          :views -> [p.views || 0, p.downloads || 0]
          :downloads -> [p.downloads || 0, p.views || 0]
        end
      end)
      |> Enum.max(fn -> 1 end)

    assigns = Map.put(assigns, :max_val, max(1, max_val))

    ~H"""
    <div class="stats-chart">
      <div class="stats-chart-header">
        <span class="stats-chart-title">
          {chart_title(@mode)}
        </span>
        <span class="stats-chart-legend">
          <%= if @mode in [:views, :downloads] do %>
            <span class="stats-legend-dot stats-legend-views"></span>
            Views <span class="stats-legend-dot stats-legend-downloads"></span>
            Downloads
          <% else %>
            <span class="stats-legend-dot stats-legend-count"></span> Count
          <% end %>
        </span>
      </div>
      <div class="stats-chart-bars">
        <%= for point <- @series do %>
          <div class="stats-chart-col">
            <div class="stats-chart-col-label">
              {point.label}
            </div>
            <div class="stats-chart-bar-wrap">
              <%= if @mode in [:views, :downloads] do %>
                <div
                  class="stats-chart-bar stats-chart-bar-views"
                  style={bar_height(point.views || 0, @max_val)}
                >
                </div>
                <div
                  class="stats-chart-bar stats-chart-bar-downloads"
                  style={bar_height(point.downloads || 0, @max_val)}
                >
                </div>
              <% else %>
                <div
                  class="stats-chart-bar stats-chart-bar-count"
                  style={bar_height(point.count || 0, @max_val)}
                >
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  OJS style date range filter toolbar used by most reports.
  """
  attr :action, :string, required: true
  attr :from, :string, required: true
  attr :to, :string, required: true
  attr :metric, :string, default: "views"
  attr :export_url, :string, required: true
  attr :show_metric, :boolean, default: true
  attr :report, :string, default: "tr"

  def stats_filter_bar(assigns) do
    ~H"""
    <form class="stats-filter-bar" method="get" action={@action}>
      <div class="stats-field">
        <label for="from">Start Date</label>
        <input
          class="settings-input stats-date-input"
          type="date"
          id="from"
          name="from"
          value={@from}
        />
      </div>
      <div class="stats-field">
        <label for="to">End Date</label>
        <input class="settings-input stats-date-input" type="date" id="to" name="to" value={@to} />
      </div>
      <%= if @show_metric do %>
        <div class="stats-field">
          <label for="metric">Metric Type</label>
          <select
            class="settings-input settings-input--dropdown stats-select"
            id="metric"
            name="metric"
          >
            <option value="views" selected={@metric == "views"}>Views</option>
            <option value="downloads" selected={@metric == "downloads"}>Downloads</option>
          </select>
        </div>
      <% end %>
      <div class="stats-field stats-field-actions">
        <button type="submit" class="btn-settings-secondary">Apply</button>
        <a class="btn-settings-secondary stats-export-btn" href={@export_url}>Export CSV</a>
      </div>
    </form>
    """
  end

  defp stats_active(current, key) when current == key, do: "active"
  defp stats_active(_current, _key), do: nil

  def total_users(rows), do: Enum.reduce(rows, 0, &(&2 + &1.count))

  def role_count(rows, key) do
    case Enum.find(rows, &(&1.key == key)) do
      nil -> 0
      row -> row.count
    end
  end

  defp chart_title(:count), do: "Monthly totals"
  defp chart_title(:downloads), do: "Views and Downloads by month"
  defp chart_title(:views), do: "Views and Downloads by month"

  defp bar_height(value, max_val) do
    pct = round(value / max_val * 100)
    "height: #{max(pct, 1)}%"
  end
end
