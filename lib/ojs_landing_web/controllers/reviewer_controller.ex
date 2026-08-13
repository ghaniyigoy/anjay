defmodule OjsLandingWeb.ReviewerController do
  use OjsLandingWeb, :controller

  def review_assignments(conn, %{"currentViewId" => view_id} = _params) do
    user = conn.assigns.current_user

    # Filter review assignments berdasarkan view_id
    all_assignments = get_reviewer_assignments(user.username)

    filtered_assignments =
      case view_id do
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

        _ ->
          all_assignments
      end

    conn
    |> put_root_layout(false)
    |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
    |> render(:review_assignments,
      assignments: filtered_assignments,
      all_assignments: all_assignments,
      current_view: view_id || "reviewer-action-required",
      user: user
    )
  end

  def review_assignments(conn, _params) do
    review_assignments(conn, %{"currentViewId" => "reviewer-action-required"})
  end

  def review(conn, %{"id" => id}) do
    if is_nil(conn.assigns.current_user) do
      conn
      |> put_flash(:error, "Silakan login terlebih dahulu untuk mengakses halaman review.")
      |> redirect(to: "/login")
    else
      do_review(conn, id)
    end
  end

  defp do_review(conn, id) do
    assignment = get_review_assignment(id)

    case assignment do
      nil ->
        conn
        |> put_flash(:error, "Review assignment not found")
        |> redirect(to: "/dashboard/reviewAssignments")

      assignment ->
        user = conn.assigns.current_user

        conn
        |> put_root_layout(false)
        |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
        |> render(:review,
          assignment: assignment,
          user: user,
          criteria: review_criteria()
        )
    end
  end

  def submit_review(conn, %{"id" => id} = params) do
    assignment = get_review_assignment(id)

    if is_nil(assignment) do
      conn
      |> put_flash(:error, "Review assignment not found")
      |> redirect(to: "/dashboard/reviewAssignments")
    else
      recommendation = params["recommendation"] || "None"

      conn
      |> put_flash(
        :info,
        "Review submitted for \"#{assignment.title}\" (recommendation: #{recommendation})."
      )
      |> redirect(to: "/review/#{id}")
    end
  end

  defp get_review_assignment(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> get_review_assignment(int)
      _ -> nil
    end
  end

  defp get_review_assignment(id) when is_integer(id) do
    Enum.find(get_reviewer_assignments(nil), &(&1.id == id))
  end

  defp review_criteria do
    [
      %{
        label: "Originality",
        question: "Is the manuscript original and does it contribute new knowledge to the field?"
      },
      %{
        label: "Relevance",
        question: "Is the manuscript relevant to the scope and focus of the journal?"
      },
      %{
        label: "Methodology",
        question: "Are the research methods sound, rigorous, and clearly described?"
      },
      %{
        label: "Data & Analysis",
        question: "Are the data, results, and analysis presented clearly and correctly?"
      },
      %{
        label: "Clarity & Structure",
        question: "Is the manuscript well-written, well-organized, and easy to follow?"
      }
    ]
  end

  # Dummy data untuk testing
  # Penambahan underscore (_) di depan reviewer_username untuk menghilangkan warning
  defp get_reviewer_assignments(_reviewer_username) do
    [
      %{
        id: 1,
        title: "Implementasi Machine Learning untuk Analisis Sentimen",
        subtitle: "Studi Komparasi Naive Bayes, SVM, dan Random Forest pada Data Twitter",
        abstract:
          "Penelitian ini membandingkan performa algoritma machine learning untuk klasifikasi sentimen pada data media sosial berbahasa Indonesia. Dataset sebesar 50.000 tweet dievaluasi menggunakan akurasi, presisi, recall, dan F1-score.",
        author: "Ahmad Fauzi",
        journal: "Jurnal Perang Dunia 1",
        section: "Artikel Penelitian",
        language: "Bahasa Indonesia",
        keywords: "machine learning, analisis sentimen, naive bayes, SVM, random forest",
        status: :action_required,
        date_assigned: ~D[2024-01-15],
        due_date: ~D[2024-02-15],
        round: 1,
        files: [
          %{name: "manuscript.pdf", type: "PDF", size: "1.4 MB", date: "2024-01-12"},
          %{name: "appendix.pdf", type: "PDF", size: "820 KB", date: "2024-01-12"}
        ],
        review_history: []
      },
      %{
        id: 2,
        title: "Sistem Rekomendasi Menggunakan Collaborative Filtering",
        subtitle: "Pendekatan Matrix Factorization dengan Implicit Feedback",
        abstract:
          "Sistem rekomendasi dikembangkan menggunakan collaborative filtering dengan matrix factorization untuk menangani data implicit feedback dari pengguna platform e-commerce.",
        author: "Siti Nurhaliza",
        journal: "Jurnal Perang Dunia 1",
        section: "Artikel Penelitian",
        language: "Bahasa Indonesia",
        keywords: "rekomendasi, collaborative filtering, matrix factorization",
        status: :completed,
        date_assigned: ~D[2024-01-10],
        due_date: ~D[2024-02-10],
        round: 1,
        files: [
          %{name: "manuscript.pdf", type: "PDF", size: "1.1 MB", date: "2024-01-05"},
          %{name: "dataset.csv", type: "CSV", size: "2.3 MB", date: "2024-01-05"}
        ],
        review_history: [
          %{
            round: 1,
            reviewer: "Dr. Siti Nurhaliza",
            decision: "Minor Revisions",
            date: "2024-02-08"
          }
        ]
      },
      %{
        id: 3,
        title: "Blockchain untuk Keamanan Data",
        subtitle: "Evaluasi Performa Konsensus Proof-of-Stake",
        abstract:
          "Studi ini mengevaluasi keamanan dan performa protokol konsensus Proof-of-Stake pada jaringan blockchain untuk aplikasi penyimpanan data sensitif.",
        author: "Budi Santoso",
        journal: "Jurnal Perang Dunia 1",
        section: "Tinjauan Literatur",
        language: "Bahasa Indonesia",
        keywords: "blockchain, keamanan data, proof-of-stake",
        status: :published,
        date_assigned: ~D[2023-12-01],
        due_date: ~D[2024-01-01],
        round: 2,
        files: [
          %{name: "manuscript-final.pdf", type: "PDF", size: "980 KB", date: "2023-12-20"}
        ],
        review_history: [
          %{
            round: 1,
            reviewer: "Dr. Bambang Wijaya",
            decision: "Major Revisions",
            date: "2023-12-15"
          },
          %{round: 2, reviewer: "Budi Santoso", decision: "Accept", date: "2024-01-15"}
        ]
      }
    ]
  end
end
