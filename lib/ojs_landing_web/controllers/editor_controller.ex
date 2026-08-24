defmodule OjsLandingWeb.EditorController do
  use OjsLandingWeb, :controller

  def editorial(conn, %{"currentViewId" => view_id} = _params) do
    user = conn.assigns.current_user

    # Filter submissions berdasarkan view_id
    all_submissions = get_editorial_submissions()

    filtered_submissions =
      case view_id do
        "assigned-to-me" ->
          Enum.filter(all_submissions, fn s -> s.assigned_to == user.username end)

        "active" ->
          Enum.filter(all_submissions, fn s -> s.status in [:active, :under_review] end)

        "needs-editor" ->
          Enum.filter(all_submissions, fn s -> s.stage == :needs_editor end)

        "initial-review" ->
          Enum.filter(all_submissions, fn s -> s.stage == :initial_review end)

        "needs-reviews" ->
          Enum.filter(all_submissions, fn s -> s.stage == :needs_reviews end)

        "awaiting-reviews" ->
          Enum.filter(all_submissions, fn s -> s.stage == :awaiting_reviews end)

        "reviews-submitted" ->
          Enum.filter(all_submissions, fn s -> s.stage == :reviews_submitted end)

        "reviews-overdue" ->
          Enum.filter(all_submissions, fn s -> s.reviews_overdue end)

        "revisions-submitted" ->
          Enum.filter(all_submissions, fn s -> s.stage == :revisions_submitted end)

        "external-review" ->
          Enum.filter(all_submissions, fn s -> s.stage == :external_review end)

        "copyediting" ->
          Enum.filter(all_submissions, fn s -> s.stage == :copyediting end)

        "production" ->
          Enum.filter(all_submissions, fn s -> s.stage == :production end)

        "scheduled" ->
          Enum.filter(all_submissions, fn s -> s.status == :scheduled end)

        "published" ->
          Enum.filter(all_submissions, fn s -> s.status == :published end)

        "declined" ->
          Enum.filter(all_submissions, fn s -> s.status == :declined end)

        _ ->
          all_submissions
      end

    conn
    |> put_root_layout(false)
    |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
    |> render(:editorial,
      submissions: filtered_submissions,
      all_submissions: all_submissions,
      current_view: view_id || "assigned-to-me",
      user: user
    )
  end

  def editorial(conn, _params) do
    editorial(conn, %{"currentViewId" => "assigned-to-me"})
  end

  # Data submission asli dari store Submission (hasil submit author)
  defp get_editorial_submissions do
    OjsLanding.Submission.all()
    |> Enum.reject(&(&1.status == :incomplete))
    |> Enum.map(&to_editorial_row/1)
  end

  defp to_editorial_row(submission) do
    %{
      id: submission.id,
      title: title_or_placeholder(submission.title),
      author: author_name(submission),
      assigned_to: "editor",
      status: submission.status,
      stage: stage_for_status(submission.status),
      days: days_since(Map.get(submission, :created_at)),
      reviews_overdue: false
    }
  end

  defp title_or_placeholder(title) when title in [nil, ""], do: "(Tanpa judul)"
  defp title_or_placeholder(title), do: title

  # Nama author diambil dari contributors submission (primary contact lebih dulu),
  # lalu fallback ke nama akun.
  defp author_name(submission) do
    case contributor_names(submission.contributors) do
      [] -> author_account_name(submission.author_username)
      names -> List.first(names)
    end
  end

  defp contributor_names(contributors) when is_list(contributors) do
    contributors
    |> Enum.sort_by(&(Map.get(&1, :primary) == true), :desc)
    |> Enum.map(&contributor_display_name/1)
    |> Enum.reject(&is_nil/1)
  end

  defp contributor_names(_), do: []

  defp contributor_display_name(contributor) when is_map(contributor) do
    name =
      String.trim("#{Map.get(contributor, :given_name)} #{Map.get(contributor, :family_name)}")

    if name == "", do: nil, else: name
  end

  defp contributor_display_name(_), do: nil

  defp author_account_name(username) do
    case OjsLanding.User.find_by_username(username) do
      nil ->
        username || "Unknown"

      user ->
        String.trim("#{user.given_name} #{user.family_name}")
    end
  end

  defp stage_for_status(:active), do: :initial_review
  defp stage_for_status(:revisions_requested), do: :external_review
  defp stage_for_status(:revisions_submitted), do: :revisions_submitted
  defp stage_for_status(:scheduled), do: :production
  defp stage_for_status(:published), do: :production
  defp stage_for_status(:declined), do: :external_review
  defp stage_for_status(_), do: :initial_review

  defp days_since(nil), do: 0

  defp days_since(%DateTime{} = datetime) do
    max(0, Date.diff(Date.utc_today(), DateTime.to_date(datetime)))
  end

  defp days_since(_), do: 0
end
