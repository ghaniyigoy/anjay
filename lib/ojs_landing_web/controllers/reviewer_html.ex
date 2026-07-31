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
  def status_label(:completed), do: "Completed"
  def status_label(:declined), do: "Declined"
  def status_label(:published), do: "Published"
  def status_label(:archived), do: "Archived"
  def status_label(_), do: "Unknown"

  def status_color(:action_required), do: "#dc3545"
  def status_color(:completed), do: "#27ae60"
  def status_color(:declined), do: "#e74c3c"
  def status_color(:published), do: "#3498db"
  def status_color(:archived), do: "#95a5a6"
end
