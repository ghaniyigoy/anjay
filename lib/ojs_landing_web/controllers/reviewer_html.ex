defmodule OjsLandingWeb.ReviewerHTML do
  use OjsLandingWeb, :html
  embed_templates "reviewer_html/*"

  def badge_class(view_id, count) do
    cond do
      view_id == "reviewer-action-required" and count > 0 -> "badge-danger"
      view_id == "reviewer-assignments-published" and count > 0 -> "badge-info"
      count > 0 -> "badge-default"
      true -> "badge-zero"
    end
  end

  def status_label(:action_required), do: "Action Required"
  def status_label(:in_progress), do: "In Progress"
  def status_label(:completed), do: "Completed"
  def status_label(:declined), do: "Declined"
  def status_label(:published), do: "Published"
  def status_label(:archived), do: "Archived"
  def status_label(_), do: "Unknown"

  def status_color(:action_required), do: "#dc3545"
  def status_color(:in_progress), do: "#f39c12"
  def status_color(:completed), do: "#27ae60"
  def status_color(:declined), do: "#e74c3c"
  def status_color(:published), do: "#3498db"
  def status_color(:archived), do: "#95a5a6"

  def all_tasks_done?(tasks), do: Enum.all?(tasks, & &1.done)
  def done_task_count(tasks), do: Enum.count(tasks, & &1.done)

  def wizard_current_step(%{status: :action_required}), do: 1
  def wizard_current_step(%{status: :in_progress, wizard_step: s}) when s in [1, 2, 3, 4], do: s
  def wizard_current_step(%{status: :completed}), do: 4
  def wizard_current_step(_), do: 1

  def wizard_step_class(assignment, num) do
    current = wizard_current_step(assignment)

    cond do
      num == current -> "active"
      num < current -> "done"
      true -> ""
    end
  end

  def truncate_title(title, limit \\ 32) when is_binary(title) do
    if String.length(title) > limit do
      String.slice(title, 0, limit - 1) <> "…"
    else
      title
    end
  end

  def format_date(%Date{} = date), do: Calendar.strftime(date, "%Y-%m-%d")
  def format_date(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d")
  def format_date(value) when is_binary(value), do: value
  def format_date(_), do: "—"

  def file_type_class("PDF"), do: "pdf"
  def file_type_class("CSV"), do: "csv"
  def file_type_class(type) when is_binary(type), do: "other"
  def file_type_class(_), do: "other"

  def reviewer_files(nil), do: []
  def reviewer_files(files), do: files

  def file_name(%{filename: name}) when is_binary(name) and name != "", do: name
  def file_name(%{name: name}) when is_binary(name) and name != "", do: name

  def file_name(file) when is_map(file),
    do: Map.get(file, :filename) || Map.get(file, :name) || ""

  def file_name(_), do: ""

  def file_type(%{genre: type}) when is_binary(type) and type != "", do: type
  def file_type(%{type: type}) when is_binary(type) and type != "", do: type

  def file_type(file) when is_map(file),
    do: Map.get(file, :genre) || Map.get(file, :type) || "Other"

  def file_type(_), do: "Other"

  def last_reply_date(discussion) do
    case discussion.replies do
      nil -> "—"
      [] -> "—"
      replies -> replies |> List.last() |> Map.get(:date, "—")
    end
  end

  def discussions(nil), do: []
  def discussions(list), do: list

  def review_participants(assignment, user) do
    reviewer =
      case assignment.reviewer_name do
        name when is_binary(name) and name != "" -> name
        _ -> participant_user_name(user)
      end

    author =
      case assignment.author do
        name when is_binary(name) and name != "" -> name
        _ -> "Author"
      end

    [
      %{name: reviewer, role: "Reviewer"},
      %{name: author, role: "Author"}
    ]
  end

  defp participant_user_name(%OjsLanding.User{given_name: given, family_name: family}) do
    String.trim("#{given} #{family}")
  end

  defp participant_user_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp participant_user_name(_), do: "Reviewer"
end
