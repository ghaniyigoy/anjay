defmodule OjsLandingWeb.ReviewerController do
  use OjsLandingWeb, :controller

  def review_assignments(conn, %{"currentViewId" => view_id} = _params) do
    user = conn.assigns.current_user

    # Filter review assignments berdasarkan view_id
    all_assignments = get_reviewer_assignments(user.username)

    filtered_assignments = case view_id do
      "reviewer-action-required" ->
        Enum.filter(all_assignments, fn a -> a.status == :action_required end)
      "reviewer-assignments-all" ->
        all_assignments
      "reviewer-assignments-completed" ->
        Enum.filter(all_assignments, fn a -> a.status == :completed end)
      "reviewer-assignments-declined" ->
        Enum.filter(all_assignments, fn a -> a.status == :declined end)
      "reviewer-assignments-published" ->
        Enum.filter(all_assignments, fn a -> a.status == :published end)
      "reviewer-assignments-archived" ->
        Enum.filter(all_assignments, fn a -> a.status == :archived end)
      _ -> all_assignments
    end

    conn
    |> put_root_layout(false)
    |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
    |> render(:review_assignments,
      assignments: filtered_assignments,
      all_assignments: all_assignments,
      current_view: view_id || "reviewer-action-required",
      user: user)
  end

  def review_assignments(conn, _params) do
    review_assignments(conn, %{"currentViewId" => "reviewer-action-required"})
  end

  # Dummy data untuk testing
  # Penambahan underscore (_) di depan reviewer_username untuk menghilangkan warning
  defp get_reviewer_assignments(_reviewer_username) do
    [
      %{
        id: 1,
        title: "Implementasi Machine Learning untuk Analisis Sentimen",
        author: "Ahmad Fauzi",
        status: :action_required,
        date_assigned: ~D[2024-01-15],
        due_date: ~D[2024-02-15]
      },
      %{
        id: 2,
        title: "Sistem Rekomendasi Menggunakan Collaborative Filtering",
        author: "Siti Nurhaliza",
        status: :completed,
        date_assigned: ~D[2024-01-10],
        due_date: ~D[2024-02-10]
      },
      %{
        id: 3,
        title: "Blockchain untuk Keamanan Data",
        author: "Budi Santoso",
        status: :published,
        date_assigned: ~D[2023-12-01],
        due_date: ~D[2024-01-01]
      }
    ]
  end
end
