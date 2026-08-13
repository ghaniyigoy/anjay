defmodule OjsLanding.Stats do
  @moduledoc """
  Deterministic dummy statistics for the OJS-style statistics dashboard.

  The application has no database, so all metrics are derived from the
  seeded journals, issues, and users and rendered in a stable, readable way.
  """

  alias OjsLanding.Issue
  alias OjsLanding.User

  @months 12

  @month_names ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  @doc """
  Publication (article) metrics rows for a journal.
  """
  def publications(journal) do
    Enum.map(journal.articles || [], fn a ->
      %{
        id: a[:id],
        title: a[:title],
        type: "Article",
        views: metric({journal.id, a[:id], :views}, 400, 15),
        downloads: metric({journal.id, a[:id], :downloads}, 320, 8)
      }
    end)
  end

  @doc """
  Monthly views/downloads series used on the Publications and Issues charts.
  """
  def monthly_series(journal) do
    month_series(@months)
    |> Enum.with_index()
    |> Enum.map(fn {m, i} ->
      %{
        label: month_label(m),
        views: metric({journal.id, i, :views}, 500, 50),
        downloads: metric({journal.id, i, :downloads}, 420, 30)
      }
    end)
  end

  @doc """
  Issue metrics rows for a journal.
  """
  def issues(journal) do
    journal.id
    |> Issue.for_journal()
    |> Enum.map(fn issue ->
      %{
        id: issue.id,
        label: issue_label(issue),
        views: metric({journal.id, issue.id, :views}, 900, 40),
        downloads: metric({journal.id, issue.id, :downloads}, 650, 20)
      }
    end)
  end

  @doc """
  Context page metrics (homepage, issue, search).
  """
  def context(journal) do
    [
      %{page: "Homepage", views: metric({journal.id, :home}, 8000, 500), downloads: 0},
      %{
        page: "Issue",
        views: metric({journal.id, :issue}, 3000, 150),
        downloads: metric({journal.id, :issue_dl}, 2000, 80)
      },
      %{
        page: "Search Results",
        views: metric({journal.id, :search}, 1200, 60),
        downloads: 0
      }
    ]
  end

  @doc """
  Monthly homepage views series used on the Context report.
  """
  def context_series(journal) do
    month_series(@months)
    |> Enum.with_index()
    |> Enum.map(fn {m, i} ->
      %{
        label: month_label(m),
        views: metric({journal.id, i, :home_series}, 700, 40),
        downloads: 0
      }
    end)
  end

  @doc """
  Editorial activity summary and monthly rows.
  """
  def editorial(journal) do
    rows =
      month_series(@months)
      |> Enum.with_index()
      |> Enum.map(fn {m, i} ->
        received = metric({journal.id, i, :received}, 25, 3)
        accepted = max(div(received, 2), metric({journal.id, i, :accepted}, 12, 1))
        declined = max(div(received, 3), metric({journal.id, i, :declined}, 8, 1))
        published = max(div(accepted, 2), metric({journal.id, i, :published}, 10, 0))

        %{
          label: month_label(m),
          received: received,
          accepted: accepted,
          declined: declined,
          published: published,
          days_first: metric({journal.id, i, :days_first}, 45, 15),
          days_final: metric({journal.id, i, :days_final}, 120, 60)
        }
      end)

    summary = %{
      received: sum(rows, :received),
      accepted: sum(rows, :accepted),
      declined: sum(rows, :declined),
      published: sum(rows, :published),
      days_first_avg: avg(rows, :days_first),
      days_final_avg: avg(rows, :days_final)
    }

    %{summary: summary, rows: rows}
  end

  @doc """
  Registered users grouped by role.
  """
  def users do
    counts = Enum.frequencies_by(User.all(), & &1.role)

    [
      %{role: "Administrator", key: :admin, count: Map.get(counts, :admin, 0)},
      %{role: "Journal Editor", key: :editor, count: Map.get(counts, :editor, 0)},
      %{role: "Reviewer", key: :reviewer, count: Map.get(counts, :reviewer, 0)},
      %{role: "Author", key: :author, count: Map.get(counts, :author, 0)}
    ]
  end

  @doc """
  COUNTER R5 title (TR) and item (IR) monthly series.
  """
  def counter_r5(journal) do
    months = month_series(@months)

    tr =
      months
      |> Enum.with_index()
      |> Enum.map(fn {m, i} ->
        %{label: month_label(m), count: metric({journal.id, i, :tr}, 600, 40)}
      end)

    ir =
      months
      |> Enum.with_index()
      |> Enum.map(fn {m, i} ->
        %{label: month_label(m), count: metric({journal.id, i, :ir}, 350, 25)}
      end)

    %{tr: tr, ir: ir}
  end

  @doc """
  Available report templates with a download target.
  """
  def reports(journal) do
    base = "/#{journal.path || String.replace(String.downcase(journal.title), " ", "_")}"

    [
      %{
        name: "Article Views",
        description: "Views of article abstract and galley pages.",
        format: "CSV",
        url: "#{base}/stats/publications/publications?export=csv"
      },
      %{
        name: "Article Downloads",
        description: "Downloads of article galley files.",
        format: "CSV",
        url: "#{base}/stats/publications/publications?export=csv"
      },
      %{
        name: "Issues",
        description: "Views and downloads of journal issues.",
        format: "CSV",
        url: "#{base}/stats/issues/issues?export=csv"
      },
      %{
        name: "Context",
        description: "Views of the journal home page and search results.",
        format: "CSV",
        url: "#{base}/stats/context/context?export=csv"
      },
      %{
        name: "Editorial Activity",
        description: "Submissions received, accepted, declined and published per month.",
        format: "CSV",
        url: "#{base}/stats/editorial/editorial?export=csv"
      },
      %{
        name: "Users",
        description: "Registered users by role.",
        format: "CSV",
        url: "#{base}/stats/users/users?export=csv"
      },
      %{
        name: "COUNTER R5",
        description: "COUNTER 5 compliant usage reports (TR / IR).",
        format: "TSV",
        url: "#{base}/stats/counterR5/counterR5?export=csv"
      }
    ]
  end

  @doc """
  Serialize a report to CSV.
  """
  def to_csv(headers, rows) do
    header_line = Enum.join(headers, ",")

    body =
      rows
      |> Enum.map(fn row -> Enum.map_join(headers, ",", &row_cell(row, &1)) end)
      |> Enum.join("\n")

    header_line <> "\n" <> body <> "\n"
  end

  @doc """
  Label for a month series entry, e.g. "Mar 2026".
  """
  def month_label(%{year: year, month: month}), do: "#{Enum.at(@month_names, month - 1)} #{year}"

  defp row_cell(row, key) when is_map_key(row, key) do
    row
    |> Map.get(key)
    |> to_string()
  end

  defp row_cell(_row, _key), do: ""

  defp sum(rows, key) do
    Enum.reduce(rows, 0, &(&2 + Map.get(&1, key)))
  end

  defp avg(rows, key) do
    case sum(rows, key) do
      0 -> 0
      total -> div(total, length(rows))
    end
  end

  defp issue_label(issue) do
    "Vol. #{issue.volume || 1}, No. #{issue.number || 1} (#{issue.year || "—"})"
  end

  defp month_series(count) do
    today = Date.utc_today()

    for i <- 0..(count - 1) do
      total = today.year * 12 + (today.month - 1) - i
      %{year: div(total, 12), month: rem(total, 12) + 1}
    end
    |> Enum.reverse()
  end

  defp metric(seed, max, min) when max > min do
    min + rem(abs(:erlang.phash2(seed)), max - min + 1)
  end
end
