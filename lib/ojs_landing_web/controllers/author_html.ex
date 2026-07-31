defmodule OjsLandingWeb.AuthorHTML do
  use OjsLandingWeb, :html
  embed_templates "author_html/*"

  def status_badge(:active), do: "badge-active"
  def status_badge(:revisions_requested), do: "badge-warning"
  def status_badge(:revisions_submitted), do: "badge-info"
  def status_badge(:incomplete), do: "badge-incomplete"
  def status_badge(:scheduled), do: "badge-scheduled"
  def status_badge(:published), do: "badge-success"
  def status_badge(:declined), do: "badge-danger"
  def status_badge(_), do: ""

  def status_text(:active), do: "Active"
  def status_text(:revisions_requested), do: "Revisions Requested"
  def status_text(:revisions_submitted), do: "Revisions Submitted"
  def status_text(:incomplete), do: "Incomplete"
  def status_text(:scheduled), do: "Scheduled for Publication"
  def status_text(:published), do: "Published"
  def status_text(:declined), do: "Declined"
  def status_text(_), do: "Unknown"
end
