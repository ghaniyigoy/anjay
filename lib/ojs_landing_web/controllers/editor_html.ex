defmodule OjsLandingWeb.EditorHTML do
  use OjsLandingWeb, :html
  embed_templates "editor_html/*"

  def badge_class(view_id, count) do
    cond do
      view_id == "reviews-overdue" and count > 0 -> "badge-danger"
      count > 0 -> "badge-default"
      true -> "badge-zero"
    end
  end

  def stage_label(:needs_editor), do: "Needs Editor"
  def stage_label(:initial_review), do: "Initial Review"
  def stage_label(:needs_reviews), do: "Needs Reviews"
  def stage_label(:awaiting_reviews), do: "Awaiting Reviews"
  def stage_label(:reviews_submitted), do: "Reviews Submitted"
  def stage_label(:external_review), do: "External Review"
  def stage_label(:copyediting), do: "Copyediting"
  def stage_label(:production), do: "Production"
  def stage_label(:scheduled), do: "Scheduled"
  def stage_label(:published), do: "Published"
  def stage_label(:declined), do: "Declined"
  def stage_label(_), do: "Submission"

  def stage_color(:needs_editor), do: "#9b59b6"
  def stage_color(:initial_review), do: "#3498db"
  def stage_color(:needs_reviews), do: "#f39c12"
  def stage_color(:awaiting_reviews), do: "#3498db"
  def stage_color(:reviews_submitted), do: "#27ae60"
  def stage_color(:external_review), do: "#9b59b6"
  def stage_color(:copyediting), do: "#e67e22"
  def stage_color(:production), do: "#e74c3c"
  def stage_color(_), do: "#95a5a6"

  def journal_settings_path do
    [journal | _] = OjsLanding.Journal.all()
    "/#{journal.path}/management/settings/context"
  end

  def journal_manage_issues_path do
    [journal | _] = OjsLanding.Journal.all()
    "/#{journal.path}/manageIssues"
  end

  def journal_dois_path do
    [journal | _] = OjsLanding.Journal.all()
    "/#{journal.path}/dois"
  end

  def journal_stats_path do
    [journal | _] = OjsLanding.Journal.all()
    "/#{journal.path}/stats/publications/publications"
  end

  def journal_settings_links do
    base = journal_settings_path() |> String.replace("/context", "")

    [
      {"Journal", "#{base}/context"},
      {"Website", "#{base}/website"},
      {"Workflow", "#{base}/workflow"},
      {"Distribution", "#{base}/distribution"},
      {"Users & Roles", "#{base}/access"}
    ]
  end

  def journal_stats_links do
    base = journal_stats_path() |> String.replace("/publications", "")

    [
      {"Publications", "#{base}/publications/publications"},
      {"Issues", "#{base}/issues/issues"},
      {"Context", "#{base}/context/context"},
      {"Editorial", "#{base}/editorial/editorial"},
      {"Users", "#{base}/users/users"},
      {"COUNTER R5", "#{base}/counterR5/counterR5"},
      {"Reports", "#{base}/reports"}
    ]
  end
end
