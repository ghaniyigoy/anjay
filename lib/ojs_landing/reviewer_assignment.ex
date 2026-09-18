defmodule OjsLanding.ReviewerAssignment do
  @moduledoc """
  Reviewer assignment store backed by an in-memory Agent.

  Keeps reviewer assignments (and their submitted reviews) in a process so a
  submitted review survives across requests and the workflow can advance to the
  next stage during the lifetime of the node.
  """

  use Agent

  defstruct [
    :id,
    :title,
    :subtitle,
    :abstract,
    :author,
    :reviewer_name,
    :journal,
    :section,
    :language,
    :keywords,
    :status,
    :date_assigned,
    :due_date,
    :round,
    :files,
    :review_history,
    :stage,
    :submitted_at,
    :recommendation,
    :comments_author,
    :comments_editor,
    :copyedit_tasks,
    :galley_files,
    :proofread_tasks,
    :published_at,
    :issue,
    :wizard_step,
    :reviewer_files,
    :discussions
  ]

  def start_link(_opts) do
    Agent.start_link(&seed/0, name: __MODULE__)
  end

  @doc """
  Get all assignments
  """
  def all do
    Agent.get(__MODULE__, & &1)
  end

  @doc """
  Get a single assignment by id
  """
  def get(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> get(int)
      _ -> nil
    end
  end

  def get(id) when is_integer(id) do
    Agent.get(__MODULE__, fn assignments -> Enum.find(assignments, &(&1.id == id)) end)
  end

  @doc """
  Reset the store to its seeded state (used in tests).
  """
  def reset do
    Agent.update(__MODULE__, fn _ -> seed() end)
  end

  @doc """
  Create a new reviewer assignment for a submission.
  """
  def create(params) do
    assignment = %__MODULE__{
      id: next_id(),
      title: params["title"] || "",
      subtitle: params["subtitle"] || "",
      abstract: params["abstract"] || "",
      author: params["author"] || "",
      reviewer_name: params["reviewer_name"] || "",
      journal: params["journal"] || "",
      section: params["section"] || "",
      language: params["language"] || "",
      keywords: params["keywords"] || "",
      status: :action_required,
      date_assigned: Date.utc_today(),
      due_date: normalize_date(params["due_date"]),
      round: params["round"] || 1,
      files: params["files"] || [],
      review_history: [],
      stage: :review,
      submitted_at: nil,
      recommendation: nil,
      comments_author: nil,
      comments_editor: nil,
      copyedit_tasks: [],
      galley_files: [],
      proofread_tasks: [],
      published_at: nil,
      issue: nil,
      wizard_step: 1,
      reviewer_files: [],
      discussions: []
    }

    Agent.update(__MODULE__, fn assignments -> [assignment | assignments] end)
    {:ok, assignment}
  end

  @doc """
  Mark an assignment as completed, advance the workflow to the next stage, and
  record the review in the assignment's history.
  """
  def submit_review(id, params) do
    id = normalize_id(id)

    case get(id) do
      nil ->
        {:error, :not_found}

      assignment ->
        recommendation = params["recommendation"]
        comments_author = params["comments_author"]
        comments_editor = params["comments_editor"]

        updated = %{
          assignment
          | status: :completed,
            stage: :copyediting,
            submitted_at: DateTime.utc_now(),
            recommendation: recommendation,
            comments_author: comments_author,
            comments_editor: comments_editor,
            review_history:
              assignment.review_history ++
                [
                  %{
                    round: assignment.round,
                    reviewer: params["reviewer"] || "You",
                    decision: recommendation,
                    date: Date.to_string(Date.utc_today())
                  }
                ]
        }

        Agent.update(__MODULE__, fn assignments ->
          Enum.map(assignments, fn a -> if a.id == id, do: updated, else: a end)
        end)

        {:ok, updated}
    end
  end

  @doc """
  Advance the workflow to the given stage (e.g. `:production`) for an assignment.
  """
  def set_stage(id, stage) when stage in [:review, :copyediting, :production] do
    id = normalize_id(id)

    case get(id) do
      nil ->
        {:error, :not_found}

      assignment ->
        updated = %{assignment | stage: stage}

        Agent.update(__MODULE__, fn assignments ->
          Enum.map(assignments, fn a -> if a.id == id, do: updated, else: a end)
        end)

        {:ok, updated}
    end
  end

  @doc """
  Accept a review assignment that is in `:action_required` status.
  Sets status to `:in_progress` so the reviewer can proceed.
  """
  def accept_assignment(id) do
    id = normalize_id(id)

    case get(id) do
      nil ->
        {:error, :not_found}

      %{status: status} = assignment
      when status in [:action_required] ->
        updated = %{assignment | status: :in_progress, wizard_step: 2}

        Agent.update(__MODULE__, fn assignments ->
          Enum.map(assignments, fn a -> if a.id == id, do: updated, else: a end)
        end)

        {:ok, updated}

      _assignment ->
        {:error, :invalid_transition}
    end
  end

  @doc """
  Decline a review assignment that is in `:action_required` or `:in_progress` status.
  Sets status to `:declined`.
  """
  def decline_assignment(id) do
    id = normalize_id(id)

    case get(id) do
      nil ->
        {:error, :not_found}

      %{status: status} = assignment
      when status in [:action_required, :in_progress] ->
        updated = %{assignment | status: :declined}

        Agent.update(__MODULE__, fn assignments ->
          Enum.map(assignments, fn a -> if a.id == id, do: updated, else: a end)
        end)

        {:ok, updated}

      _assignment ->
        {:error, :invalid_transition}
    end
  end

  @doc """
  Advance a reviewer in the step-by-step wizard (Request -> Guidelines ->
  Download & Review -> Completion). Only allowed while the assignment is
  `:in_progress`. Returns `{:ok, assignment}` with the next step, or
  `{:error, :invalid_transition}`.
  """
  def advance_review_step(id), do: advance_review_step(id, %{})

  def advance_review_step(id, params) do
    id = normalize_id(id)

    case get(id) do
      nil ->
        {:error, :not_found}

      %{status: :in_progress, wizard_step: step} = assignment
      when step in [1, 2, 3] ->
        updated = %{
          assignment
          | wizard_step: step + 1,
            recommendation: Map.get(params, "recommendation", assignment.recommendation),
            comments_author: Map.get(params, "comments_author", assignment.comments_author),
            comments_editor: Map.get(params, "comments_editor", assignment.comments_editor)
        }

        Agent.update(__MODULE__, fn assignments ->
          Enum.map(assignments, fn a -> if a.id == id, do: updated, else: a end)
        end)

        {:ok, updated}

      _assignment ->
        {:error, :invalid_transition}
    end
  end

  @doc """
  Move a reviewer back one step in the step-by-step wizard (Download & Review ->
  Guidelines -> Request). Only allowed while the assignment is `:in_progress`.
  Returns `{:ok, assignment}` or `{:error, :invalid_transition}`.
  """
  def go_back_review_step(id) do
    id = normalize_id(id)

    case get(id) do
      nil ->
        {:error, :not_found}

      %{status: :in_progress, wizard_step: step} = assignment
      when step in [2, 3, 4] ->
        updated = %{assignment | wizard_step: max(step - 1, 1)}

        Agent.update(__MODULE__, fn assignments ->
          Enum.map(assignments, fn a -> if a.id == id, do: updated, else: a end)
        end)

        {:ok, updated}

      _assignment ->
        {:error, :invalid_transition}
    end
  end

  @doc """
  Mark a copyediting task (`"initial"`, `"author"`, or `"final"`) as complete.
  """
  def complete_copyedit_task(id, key) when key in ["initial", "author", "final"] do
    id = normalize_id(id)

    case get(id) do
      nil ->
        {:error, :not_found}

      assignment ->
        updated = %{assignment | copyedit_tasks: mark_task_done(assignment.copyedit_tasks, key)}

        Agent.update(__MODULE__, fn assignments ->
          Enum.map(assignments, fn a -> if a.id == id, do: updated, else: a end)
        end)

        {:ok, updated}
    end
  end

  @doc """
  Mark a proofreading task (`"author"` or `"proofreader"`) as complete.
  """
  def complete_proofread_task(id, key) when key in ["author", "proofreader"] do
    id = normalize_id(id)

    case get(id) do
      nil ->
        {:error, :not_found}

      assignment ->
        updated = %{assignment | proofread_tasks: mark_task_done(assignment.proofread_tasks, key)}

        Agent.update(__MODULE__, fn assignments ->
          Enum.map(assignments, fn a -> if a.id == id, do: updated, else: a end)
        end)

        {:ok, updated}
    end
  end

  @doc """
  Add a galley file to an assignment during the production stage.
  """
  def add_galley_file(id, params) do
    id = normalize_id(id)

    case get(id) do
      nil ->
        {:error, :not_found}

      assignment ->
        galley = %{
          id: next_galley_id(assignment.galley_files),
          name: params["name"],
          type: params["type"] || "PDF",
          size: params["size"] || "—",
          date: Date.to_string(Date.utc_today())
        }

        updated = %{assignment | galley_files: assignment.galley_files ++ [galley]}

        Agent.update(__MODULE__, fn assignments ->
          Enum.map(assignments, fn a -> if a.id == id, do: updated, else: a end)
        end)

        {:ok, updated}
    end
  end

  @doc """
  Add a reviewer-uploaded file to an assignment (Reviewer Files panel).
  """
  def add_reviewer_file(id, params) do
    id = normalize_id(id)

    case get(id) do
      nil ->
        {:error, :not_found}

      assignment ->
        file = %{
          id: next_reviewer_file_id(assignment.reviewer_files),
          name: params["name"] || "unnamed",
          type: params["type"] || "File",
          size: params["size"] || "—",
          date: Date.to_string(Date.utc_today())
        }

        updated = %{assignment | reviewer_files: (assignment.reviewer_files || []) ++ [file]}

        Agent.update(__MODULE__, fn assignments ->
          Enum.map(assignments, fn a -> if a.id == id, do: updated, else: a end)
        end)

        {:ok, updated}
    end
  end

  @doc """
  Add a review discussion thread to an assignment (Review Discussions panel).
  """
  def add_discussion(id, params) do
    id = normalize_id(id)

    case get(id) do
      nil ->
        {:error, :not_found}

      assignment ->
        discussion = %{
          id: next_discussion_id(assignment.discussions),
          subject: params["subject"] || "Discussion",
          message: params["message"] || "",
          author: params["author"] || "You",
          date: Date.to_string(Date.utc_today()),
          replies: []
        }

        updated = %{assignment | discussions: (assignment.discussions || []) ++ [discussion]}

        Agent.update(__MODULE__, fn assignments ->
          Enum.map(assignments, fn a -> if a.id == id, do: updated, else: a end)
        end)

        {:ok, updated}
    end
  end

  @doc """
  Publish a submission that is in the production stage.
  """
  def publish(id, params) do
    id = normalize_id(id)

    case get(id) do
      nil ->
        {:error, :not_found}

      assignment ->
        updated = %{
          assignment
          | status: :published,
            published_at: DateTime.utc_now(),
            issue: params["issue"] || "Current Issue"
        }

        Agent.update(__MODULE__, fn assignments ->
          Enum.map(assignments, fn a -> if a.id == id, do: updated, else: a end)
        end)

        {:ok, updated}
    end
  end

  defp mark_task_done(tasks, key) do
    Enum.map(tasks, fn task ->
      if task.key == key, do: %{task | done: true}, else: task
    end)
  end

  defp next_galley_id(files) do
    (files |> Enum.map(& &1.id) |> Enum.max(fn -> 0 end)) + 1
  end

  defp next_reviewer_file_id(files) when files in [nil, []], do: 1

  defp next_reviewer_file_id(files) do
    (files |> Enum.map(& &1.id) |> Enum.max()) + 1
  end

  defp next_discussion_id([]), do: 1
  defp next_discussion_id(nil), do: 1

  defp next_discussion_id(discussions) do
    (discussions |> Enum.map(& &1.id) |> Enum.max()) + 1
  end

  defp copyedit_tasks(done_keys) when is_list(done_keys) do
    [
      %{key: "initial", label: "Initial Copyedit", done: "initial" in done_keys},
      %{key: "author", label: "Author Copyedit", done: "author" in done_keys},
      %{key: "final", label: "Final Copyedit", done: "final" in done_keys}
    ]
  end

  defp proofread_tasks(done_keys) when is_list(done_keys) do
    [
      %{key: "author", label: "Author Proofread", done: "author" in done_keys},
      %{key: "proofreader", label: "Proofreader Proofread", done: "proofreader" in done_keys}
    ]
  end

  defp normalize_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> id
    end
  end

  defp normalize_id(id), do: id

  defp normalize_date(%Date{} = date), do: date

  defp normalize_date(%DateTime{} = datetime), do: DateTime.to_date(datetime)

  defp normalize_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> Date.utc_today()
    end
  end

  defp normalize_date(_), do: Date.utc_today()

  defp next_id do
    Agent.get(__MODULE__, fn assignments ->
      case Enum.map(assignments, & &1.id) do
        [] -> 1
        ids -> Enum.max(ids) + 1
      end
    end)
  end

  defp seed do
    [
      %__MODULE__{
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
        status: :in_progress,
        date_assigned: ~D[2026-08-20],
        due_date: ~D[2026-09-20],
        round: 1,
        stage: :review,
        files: [
          %{name: "manuscript.pdf", type: "PDF", size: "1.4 MB", date: "2026-08-12"},
          %{name: "appendix.pdf", type: "PDF", size: "820 KB", date: "2026-08-12"}
        ],
        review_history: [],
        copyedit_tasks: copyedit_tasks([]),
        galley_files: [],
        proofread_tasks: proofread_tasks([]),
        wizard_step: 2
      },
      %__MODULE__{
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
        date_assigned: ~D[2026-07-10],
        due_date: ~D[2026-08-10],
        round: 1,
        stage: :copyediting,
        files: [
          %{name: "manuscript.pdf", type: "PDF", size: "1.1 MB", date: "2026-07-05"},
          %{name: "dataset.csv", type: "CSV", size: "2.3 MB", date: "2026-07-05"}
        ],
        review_history: [
          %{
            round: 1,
            reviewer: "Dr. Siti Nurhaliza",
            decision: "Minor Revisions",
            date: "2026-08-08"
          }
        ],
        copyedit_tasks: copyedit_tasks(["initial", "author"]),
        galley_files: [],
        proofread_tasks: proofread_tasks([]),
        wizard_step: 4
      },
      %__MODULE__{
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
        date_assigned: ~D[2026-06-01],
        due_date: ~D[2026-07-01],
        round: 2,
        stage: :production,
        files: [
          %{name: "manuscript-final.pdf", type: "PDF", size: "980 KB", date: "2026-12-20"}
        ],
        review_history: [
          %{
            round: 1,
            reviewer: "Dr. Bambang Wijaya",
            decision: "Major Revisions",
            date: "2026-12-15"
          },
          %{round: 2, reviewer: "Budi Santoso", decision: "Accept", date: "2026-01-15"}
        ],
        copyedit_tasks: copyedit_tasks(["initial", "author", "final"]),
        galley_files: [
          %{id: 1, name: "galley-pdf.pdf", type: "PDF", size: "1.2 MB", date: "2026-01-20"},
          %{id: 2, name: "galley-html.html", type: "HTML", size: "480 KB", date: "2026-01-22"}
        ],
        proofread_tasks: proofread_tasks(["author", "proofreader"]),
        published_at: DateTime.new!(~D[2026-01-30], ~T[09:00:00]),
        issue: "Vol. 1 No. 1",
        wizard_step: 4
      },
      %__MODULE__{
        id: 4,
        title: "Deteksi Berita Palsu pada Media Sosial Menggunakan Transformer",
        subtitle: "Studi Komparasi BERT dan GPT terhadap Korpora Bahasa Indonesia",
        abstract:
          "Penelitian ini mengembangkan model klasifikasi berbasis arsitektur Transformer untuk mendeteksi berita palsu pada media sosial berbahasa Indonesia.",
        author: "Ahmad Fauzi",
        journal: "Jurnal Perang Dunia 1",
        section: "Artikel Penelitian",
        language: "Bahasa Indonesia",
        keywords: "berita palsu, transformer, BERT, NLP",
        status: :action_required,
        date_assigned: ~D[2026-08-22],
        due_date: ~D[2026-09-22],
        round: 1,
        stage: :review,
        files: [
          %{name: "manuscript.pdf", type: "PDF", size: "1.4 MB", date: "2026-08-11"},
          %{name: "dataset-berita.csv", type: "CSV", size: "3.2 MB", date: "2026-08-10"}
        ],
        review_history: [],
        copyedit_tasks: copyedit_tasks([]),
        galley_files: [],
        proofread_tasks: proofread_tasks([]),
        wizard_step: 1
      },
      %__MODULE__{
        id: 5,
        title: "Optimasi Algoritma Genetika pada Penjadwalan Produksi",
        subtitle: "Perbandingan dengan Metode Simulated Annealing",
        abstract:
          "Makalah ini mengevaluasi performa algoritma genetika yang dioptimasi untuk masalah penjadwalan produksi job-shop dibandingkan dengan simulated annealing.",
        author: "Ahmad Fauzi",
        journal: "Jurnal Perang Dunia 1",
        section: "Artikel Penelitian",
        language: "Bahasa Indonesia",
        keywords: "algoritma genetika, simulated annealing, penjadwalan, optimasi",
        status: :in_progress,
        date_assigned: ~D[2026-08-15],
        due_date: ~D[2026-09-15],
        round: 1,
        stage: :review,
        files: [
          %{name: "manuscript-rev2.pdf", type: "PDF", size: "980 KB", date: "2026-08-01"}
        ],
        review_history: [],
        copyedit_tasks: copyedit_tasks([]),
        galley_files: [],
        proofread_tasks: proofread_tasks([]),
        wizard_step: 4
      },
      %__MODULE__{
        id: 6,
        title: "Integrasi IoT untuk Monitoring Kualitas Udara Berbasis LoRa",
        subtitle: "",
        abstract:
          "Makalah ini mengimplementasikan jaringan sensor IoT menggunakan LoRa untuk memantau kualitas udara secara real-time pada area kampus.",
        author: "Ahmad Fauzi",
        journal: "Jurnal Perang Dunia 1",
        section: "Tinjauan Literatur",
        language: "Bahasa Indonesia",
        keywords: "IoT, LoRa, monitoring, kualitas udara",
        status: :declined,
        date_assigned: ~D[2026-07-20],
        due_date: ~D[2026-08-20],
        round: 1,
        stage: :review,
        files: [
          %{name: "manuscript.pdf", type: "PDF", size: "1.1 MB", date: "2026-08-08"}
        ],
        review_history: [],
        copyedit_tasks: copyedit_tasks([]),
        galley_files: [],
        proofread_tasks: proofread_tasks([]),
        wizard_step: 4
      },
      %__MODULE__{
        id: 7,
        title: "Arsitektur Microservices untuk Skalabilitas Aplikasi E-Commerce",
        subtitle: "Pendekatan Event-Driven dengan Kafka",
        abstract:
          "Studi ini membahas desain arsitektur microservices berbasis event-driven untuk meningkatkan skalabilitas platform e-commerce yang menangani jutaan transaksi harian.",
        author: "Rina Widyastuti",
        journal: "Jurnal Perang Dunia 1",
        section: "Artikel Penelitian",
        language: "Bahasa Indonesia",
        keywords: "microservices, e-commerce, kafka, skalabilitas",
        status: :archived,
        date_assigned: ~D[2026-05-10],
        due_date: ~D[2026-06-10],
        round: 1,
        stage: :review,
        files: [
          %{name: "manuscript-archived.pdf", type: "PDF", size: "1.2 MB", date: "2026-05-05"}
        ],
        review_history: [
          %{round: 1, reviewer: "Rina Widyastuti", decision: "Decline", date: "2026-06-08"}
        ],
        copyedit_tasks: copyedit_tasks([]),
        galley_files: [],
        proofread_tasks: proofread_tasks([]),
        wizard_step: 4
      }
    ]
  end
end
