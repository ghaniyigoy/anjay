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
    :issue
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
        status: :action_required,
        date_assigned: ~D[2024-01-15],
        due_date: ~D[2024-02-15],
        round: 1,
        stage: :review,
        files: [
          %{name: "manuscript.pdf", type: "PDF", size: "1.4 MB", date: "2024-01-12"},
          %{name: "appendix.pdf", type: "PDF", size: "820 KB", date: "2024-01-12"}
        ],
        review_history: [],
        copyedit_tasks: copyedit_tasks([]),
        galley_files: [],
        proofread_tasks: proofread_tasks([])
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
        date_assigned: ~D[2024-01-10],
        due_date: ~D[2024-02-10],
        round: 1,
        stage: :copyediting,
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
        ],
        copyedit_tasks: copyedit_tasks(["initial", "author"]),
        galley_files: [],
        proofread_tasks: proofread_tasks([])
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
        date_assigned: ~D[2023-12-01],
        due_date: ~D[2024-01-01],
        round: 2,
        stage: :production,
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
        ],
        copyedit_tasks: copyedit_tasks(["initial", "author", "final"]),
        galley_files: [
          %{id: 1, name: "galley-pdf.pdf", type: "PDF", size: "1.2 MB", date: "2024-01-20"},
          %{id: 2, name: "galley-html.html", type: "HTML", size: "480 KB", date: "2024-01-22"}
        ],
        proofread_tasks: proofread_tasks(["author", "proofreader"]),
        published_at: DateTime.new!(~D[2024-01-30], ~T[09:00:00]),
        issue: "Vol. 1 No. 1"
      }
    ]
  end
end
