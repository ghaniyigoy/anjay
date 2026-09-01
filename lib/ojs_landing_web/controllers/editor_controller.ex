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

  def submission_detail(conn, params) do
    user = conn.assigns.current_user

    %{"id" => id} = params
    section = params["section"]

    submission = Enum.find(get_submission_details(), fn s -> s.id == String.to_integer(id) end)

    if submission do
      section = normalize_section(section)

      conn
      |> put_root_layout(false)
      |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
      |> render(section_template(section),
        submission: submission,
        user: user,
        all_submissions: get_editorial_submissions(),
        active_section: section
      )
    else
      conn
      |> put_flash(:error, "Submission not found.")
      |> redirect(to: "/dashboard/editorial?currentViewId=assigned-to-me")
    end
  end

  # Normalize supported sections; anything unknown falls back to the
  # Submission workflow (the initial view of a submission detail).
  defp normalize_section(section) do
    if section in [
         "submission",
         "review",
         "copyediting",
         "production",
         "title-abstract",
         "contributors",
         "metadata",
         "references",
         "jats-xml",
         "galley",
         "permissions",
         "issue"
       ] do
      section
    else
      "submission"
    end
  end

  defp section_template("submission"), do: "submission_detail.html"
  defp section_template("review"), do: "review_workflow.html"
  defp section_template("copyediting"), do: "copyediting_workflow.html"
  defp section_template("production"), do: "production_workflow.html"
  defp section_template("title-abstract"), do: "title_abstract.html"
  defp section_template("contributors"), do: "contributors.html"
  defp section_template("metadata"), do: "metadata.html"
  defp section_template("references"), do: "references.html"
  defp section_template("jats-xml"), do: "jats_xml.html"
  defp section_template("galley"), do: "galley.html"
  defp section_template("permissions"), do: "permissions.html"
  defp section_template("issue"), do: "issue.html"
  defp section_template(_), do: "submission_detail.html"

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
        ],
        reviews: [
          %{
            round: 1,
            reviewers: [
              %{
                name: "Dr. Ratna Dewi",
                assigned: "2026-08-25",
                due: "2026-09-08",
                status: "Out for Review",
                recommendation: nil,
                round: 1
              },
              %{
                name: "Dr. Hendra Wijaya",
                assigned: "2026-08-26",
                due: "2026-09-09",
                status: "Acknowledgement",
                recommendation: nil,
                round: 1
              }
            ]
          },
          %{
            round: 2,
            reviewers: []
          }
        ],
        round_discussions: [
          %{
            name: "Round 1 Discussion",
            from: "Ed. Budi Santoso",
            previous_reply: "Please address reviewer concerns ...",
            replies: 3,
            closed: false
          }
        ],
        copyedit_files: [
          %{
            name: "manuscript-copyedit.docx",
            uploaded: "2026-09-04",
            type: "Copyedit File",
            size: "2.5 MB"
          },
          %{
            name: "author-confirm.docx",
            uploaded: "2026-09-05",
            type: "Author Proof",
            size: "680 KB"
          }
        ],
        copyedit_discussions: [
          %{
            name: "Copyediting",
            from: "Copyeditor: Nina Putri",
            previous_reply: "Punctuation and references updated.",
            replies: 2,
            closed: false
          }
        ],
        copyedit_status: "In Progress",
        production_files: [
          %{
            name: "layout-final.pdf",
            uploaded: "2026-09-10",
            type: "Production Ready",
            size: "3.1 MB"
          }
        ],
        production_discussions: [
          %{
            name: "Production",
            from: "Layout: Rudi Hartono",
            previous_reply: "Galley layout is ready for review.",
            replies: 1,
            closed: false
          }
        ],
        contributors: [
          %{name: "Ahmad Fauzi", role: "Author", primary: true},
          %{name: "Budi Santoso", role: "Author", primary: false}
        ],
        keywords: "machine learning, sentiment analysis, NLP",
        references:
          "Bengio, Y., & LeCun, Y. (2007). Scaling learning algorithms towards AI.\nBishop, C. M. (2006). Pattern Recognition and Machine Learning.",
        galleys: [],
        license_url: "https://creativecommons.org/licenses/by/4.0/",
        copyright_holder: nil,
        copyright_year: nil,
        sections: ["Articles", "Reviews", "Case Studies"],
        section: "Articles",
        abstract:
          "This study explores the application of machine learning techniques for sentiment analysis of Indonesian-language social media text. A supervised learning approach was used to classify opinions into positive, negative, and neutral sentiment classes, achieving competitive accuracy on the evaluation dataset."
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
        ],
        reviews: [
          %{
            round: 1,
            reviewers: [
              %{
                name: "Dr. Maya Lestari",
                assigned: "2026-08-22",
                due: "2026-09-01",
                status: "Review Submitted",
                recommendation: "Minor Revisions",
                round: 1
              },
              %{
                name: "Dr. Andi Pratama",
                assigned: "2026-08-23",
                due: "2026-09-03",
                status: "Overdue",
                recommendation: nil,
                round: 1
              }
            ]
          },
          %{
            round: 2,
            reviewers: [
              %{
                name: "Dr. Bambang Susilo",
                assigned: "2026-09-06",
                due: "2026-09-20",
                status: "Out for Review",
                recommendation: nil,
                round: 2
              }
            ]
          }
        ],
        round_discussions: [
          %{
            name: "Round 1 Discussion",
            from: "Ed. Budi Santoso",
            previous_reply: "Consolidating reviewer feedback ...",
            replies: 4,
            closed: true
          },
          %{
            name: "Round 2 Discussion",
            from: "Ed. Budi Santoso",
            previous_reply: "Second round revision requested.",
            replies: 1,
            closed: false
          }
        ],
        copyedit_files: [],
        copyedit_discussions: [
          %{
            name: "Copyediting",
            from: "Copyeditor: Nina Putri",
            previous_reply: "Awaiting final manuscript.",
            replies: 0,
            closed: false
          }
        ],
        copyedit_status: "Not Started",
        production_files: [],
        production_discussions: [
          %{
            name: "Production",
            from: "Layout: Rudi Hartono",
            previous_reply: "Waiting for copyediting to finish.",
            replies: 0,
            closed: false
          }
        ],
        contributors: [
          %{name: "Siti Nurhaliza", role: "Author", primary: true},
          %{name: "Rina Kusuma", role: "Author", primary: false}
        ],
        keywords: "collaborative filtering, recommender system",
        references:
          "Sarwar, B., Karypis, G., Konstan, J., & Riedl, J. (2001). Item-based collaborative filtering.",
        galleys: [],
        license_url: "https://creativecommons.org/licenses/by-sa/4.0/",
        copyright_holder: nil,
        copyright_year: nil,
        sections: ["Articles", "Reviews", "Case Studies"],
        section: "Articles",
        abstract:
          "This paper presents a collaborative filtering-based recommender system tailored for Open Journal Systems. The proposed method combines user-based and item-based filtering to generate personalized article recommendations, addressing data sparsity through matrix factorization."
      }
    ]
  end
end
