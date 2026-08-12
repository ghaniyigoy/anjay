defmodule OjsLandingWeb.JournalHTML do
  use OjsLandingWeb, :html

  # Mendaftarkan semua template di folder journal_html/
  embed_templates "journal_html/*"

  # --- Submission workflow helpers -----------------------------------------

  def status_badge(:active), do: "badge-active"
  def status_badge(:revisions_requested), do: "badge-warning"
  def status_badge(:revisions_submitted), do: "badge-info"
  def status_badge(:incomplete), do: "badge-incomplete"
  def status_badge(:scheduled), do: "badge-scheduled"
  def status_badge(:published), do: "badge-success"
  def status_badge(:declined), do: "badge-danger"
  def status_badge(_), do: "badge-incomplete"

  def status_text(:active), do: "Active"
  def status_text(:revisions_requested), do: "Revisions Requested"
  def status_text(:revisions_submitted), do: "Revisions Submitted"
  def status_text(:incomplete), do: "Incomplete"
  def status_text(:scheduled), do: "Scheduled for Publication"
  def status_text(:published), do: "Published"
  def status_text(:declined), do: "Declined"
  def status_text(_), do: "Unknown"

  def review_status_text(:accepted), do: "Accepted"
  def review_status_text(:revision_submitted), do: "Revision Submitted"
  def review_status_text(:revision_requested), do: "Revision Requested"
  def review_status_text(:in_review), do: "In Review"
  def review_status_text(:declined), do: "Declined"
  def review_status_text(_), do: "Not Started"

  def type_text(:article), do: "Article"
  def type_text(:review), do: "Review"
  def type_text(_), do: "Article"

  def language_name("en"), do: "English"
  def language_name(_), do: "Indonesian"

  def format_date(%DateTime{} = datetime) do
    datetime
    |> Calendar.strftime("%d %b %Y")
    |> trim_leading_zero_day()
  end

  def format_date(%Date{} = date) do
    date
    |> Calendar.strftime("%d %b %Y")
    |> trim_leading_zero_day()
  end

  def format_date(_), do: "—"

  defp trim_leading_zero_day("0" <> rest), do: rest
  defp trim_leading_zero_day(value), do: value

  def short_name(%{family_name: name}) when name not in [nil, ""], do: name
  def short_name(%{given_name: name}), do: name
  def short_name(_), do: "?"

  def not_blank(value, fallback),
    do: if(is_binary(value) and value != "", do: value, else: fallback)
end
