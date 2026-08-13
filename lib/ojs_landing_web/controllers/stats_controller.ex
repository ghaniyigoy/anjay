defmodule OjsLandingWeb.StatsController do
  use OjsLandingWeb, :controller
  plug OjsLandingWeb.Plugs.Auth, :require_editor_admin

  alias OjsLanding.Journal
  alias OjsLanding.Stats

  def publications(conn, %{"journal_path" => journal_path} = params) do
    with_journal(conn, journal_path, fn journal ->
      rows = Stats.publications(journal)

      if export?(params) do
        csv(conn, "publications.csv", [:id, :title, :type, :views, :downloads], rows)
      else
        render_stats(conn, :publications, journal, journal_path,
          rows: rows,
          series: Stats.monthly_series(journal),
          from: params["from"] || "2026-01-01",
          to: params["to"] || Date.to_string(Date.utc_today()),
          metric: params["metric"] || "views"
        )
      end
    end)
  end

  def issues(conn, %{"journal_path" => journal_path} = params) do
    with_journal(conn, journal_path, fn journal ->
      rows = Stats.issues(journal)

      if export?(params) do
        csv(conn, "issues.csv", [:id, :label, :views, :downloads], rows)
      else
        render_stats(conn, :issues, journal, journal_path,
          rows: rows,
          series: Stats.monthly_series(journal),
          from: params["from"] || "2026-01-01",
          to: params["to"] || Date.to_string(Date.utc_today()),
          metric: params["metric"] || "views"
        )
      end
    end)
  end

  def context(conn, %{"journal_path" => journal_path} = params) do
    with_journal(conn, journal_path, fn journal ->
      rows = Stats.context(journal)

      if export?(params) do
        csv(conn, "context.csv", [:page, :views, :downloads], rows)
      else
        render_stats(conn, :context, journal, journal_path,
          rows: rows,
          series: Stats.context_series(journal),
          from: params["from"] || "2026-01-01",
          to: params["to"] || Date.to_string(Date.utc_today()),
          metric: params["metric"] || "views"
        )
      end
    end)
  end

  def editorial(conn, %{"journal_path" => journal_path} = params) do
    with_journal(conn, journal_path, fn journal ->
      data = Stats.editorial(journal)

      if export?(params) do
        headers = [:label, :received, :accepted, :declined, :published, :days_first, :days_final]
        csv(conn, "editorial.csv", headers, data.rows)
      else
        render_stats(conn, :editorial, journal, journal_path,
          editorial: data,
          from: params["from"] || "2026-01-01",
          to: params["to"] || Date.to_string(Date.utc_today())
        )
      end
    end)
  end

  def users(conn, %{"journal_path" => journal_path} = params) do
    with_journal(conn, journal_path, fn journal ->
      rows = Stats.users()

      if export?(params) do
        csv(conn, "users.csv", [:role, :count], rows)
      else
        render_stats(conn, :users, journal, journal_path, rows: rows)
      end
    end)
  end

  def counter_r5(conn, %{"journal_path" => journal_path} = params) do
    with_journal(conn, journal_path, fn journal ->
      data = Stats.counter_r5(journal)
      report = params["report"] || "tr"
      series = Map.fetch!(data, String.to_existing_atom(report))

      if export?(params) do
        csv(conn, "counter_r5.csv", [:label, :count], series)
      else
        render_stats(conn, :counter_r5, journal, journal_path,
          data: data,
          report: report,
          series: series,
          from: params["from"] || "2026-01-01",
          to: params["to"] || Date.to_string(Date.utc_today())
        )
      end
    end)
  end

  def reports(conn, %{"journal_path" => journal_path}) do
    with_journal(conn, journal_path, fn journal ->
      render_stats(conn, :reports, journal, journal_path, rows: Stats.reports(journal))
    end)
  end

  defp render_stats(conn, template, journal, journal_path, extra) do
    conn
    |> put_root_layout(false)
    |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
    |> render(
      template,
      Map.merge(Map.new(extra), %{
        journal: journal,
        journal_path: journal_path,
        journal_title: journal.title,
        section: template,
        page_title: "#{section_title(template)} - #{journal.title}"
      })
    )
  end

  defp with_journal(conn, journal_path, fun) do
    case find_journal_by_path(journal_path) do
      nil ->
        conn
        |> put_flash(:error, "Journal not found")
        |> redirect(to: "/")

      journal ->
        fun.(journal)
    end
  end

  defp find_journal_by_path(path) do
    Enum.find(Journal.all(), fn journal ->
      journal_path = journal.path || String.replace(String.downcase(journal.title), " ", "_")
      journal_path == path
    end)
  end

  defp export?(params), do: params["export"] == "csv"

  defp csv(conn, filename, headers, rows) do
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, Stats.to_csv(headers, rows))
  end

  defp section_title(:publications), do: "Publications"
  defp section_title(:issues), do: "Issues"
  defp section_title(:context), do: "Context"
  defp section_title(:editorial), do: "Editorial"
  defp section_title(:users), do: "Users"
  defp section_title(:counter_r5), do: "COUNTER R5"
  defp section_title(:reports), do: "Reports"
end
