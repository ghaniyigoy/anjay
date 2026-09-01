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

  def submission_detail(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    submission = Enum.find(get_submission_details(), fn s -> s.id == String.to_integer(id) end)

    if submission do
      conn
      |> put_root_layout(false)
      |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
      |> render(:submission_detail,
        submission: submission,
        user: user,
        all_submissions: get_editorial_submissions()
      )
    else
      conn
      |> put_flash(:error, "Submission not found.")
      |> redirect(to: "/dashboard/editorial?currentViewId=assigned-to-me")
    end
  end

  # Dummy data untuk testing
  defp get_editorial_submissions do
    [
      %{
        id: 1,
        title: "Implementasi Machine Learning untuk Analisis Sentimen",
        author: "Ahmad Fauzi",
        assigned_to: "editor",
        status: :active,
        stage: :initial_review,
        days: 5,
        reviews_overdue: false
      },
      %{
        id: 2,
        title: "Sistem Rekomendasi Menggunakan Collaborative Filtering",
        author: "Siti Nurhaliza",
        assigned_to: "editor",
        status: :under_review,
        stage: :awaiting_reviews,
        days: 12,
        reviews_overdue: true
      }
    ]
  end

  # Rich dummy detail data for the submission detail page (no database yet)
  defp get_submission_details do
    [
      %{
        id: 1,
        title: "Implementasi Machine Learning untuk Analisis Sentimen",
        author: "Ahmad Fauzi",
        assigned_to: "editor",
        status: :active,
        stage: :initial_review,
        stage_label: "Initial Review",
        days: 5,
        reviews_overdue: false,
        language: "English",
        files: [
          %{
            name: "manuscript.docx",
            uploaded: "2026-09-01",
            type: "Main Submission File",
            size: "2.4 MB"
          }
        ],
        discussions: [
          %{
            name: "Editor",
            from: "Ahmad Fauzi",
            previous_reply: "Thank you for the ...",
            replies: 1,
            closed: false
          }
        ],
        participants: [
          %{name: "Prof. Budi Santoso", role: "Editor"}
        ]
      },
      %{
        id: 2,
        title: "Sistem Rekomendasi Menggunakan Collaborative Filtering",
        author: "Siti Nurhaliza",
        assigned_to: "editor",
        status: :under_review,
        stage: :awaiting_reviews,
        stage_label: "Awaiting Reviews",
        days: 12,
        reviews_overdue: true,
        language: "English",
        files: [
          %{
            name: "manuscript.docx",
            uploaded: "2026-08-28",
            type: "Main Submission File",
            size: "1.9 MB"
          }
        ],
        discussions: [
          %{
            name: "Review Round 1",
            from: "Rev. Dr. Siti Nurhaliza",
            previous_reply: "The methodology is ...",
            replies: 2,
            closed: false
          }
        ],
        participants: [
          %{name: "Prof. Budi Santoso", role: "Editor"}
        ]
      }
    ]
  end
end
