defmodule OjsLanding.Submission do
  @moduledoc """
  Submission module with an in-memory store (Agent).

  Keeps submissions in a process so that newly created submissions from the
  author workflow survive across requests during the lifetime of the node.
  """

  use Agent

  @type status ::
          :active
          | :revisions_requested
          | :revisions_submitted
          | :incomplete
          | :scheduled
          | :published
          | :declined

  defstruct [
    :id,
    :author_username,
    :title,
    :subtitle,
    :abstract,
    :section,
    :keywords,
    :language,
    :references,
    :type,
    :status,
    :stage,
    :files,
    :contributors,
    :editors,
    :editor_comments,
    :comments_to_editor,
    :discussions,
    :editor_replies,
    :checklist_agreed,
    :privacy_consent,
    :review,
    :created_at,
    :date_submitted
  ]

  def start_link(_opts) do
    Agent.start_link(fn -> seed() end, name: __MODULE__)
  end

  @doc """
  Get all submissions (newest first)
  """
  def all do
    Agent.get(__MODULE__, fn subs -> Enum.sort_by(subs, & &1.id, :desc) end)
  end

  @doc """
  Get submissions by author username
  """
  def get_by_author(username) do
    Agent.get(__MODULE__, fn subs ->
      subs
      |> Enum.filter(fn s -> s.author_username == username end)
      |> Enum.sort_by(& &1.id, :desc)
    end)
  end

  @doc """
  Get a single submission (any author)
  """
  def get(id) when is_integer(id) do
    Agent.get(__MODULE__, fn subs -> Enum.find(subs, fn s -> s.id == id end) end)
  end

  def get(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> get(int)
      :error -> nil
    end
  end

  @doc """
  Create a new (incomplete) submission for an author.
  """
  def create(author_username), do: create(author_username, "")

  @doc """
  Create a new (incomplete) submission for an author with an initial title.
  """
  def create(author_username, title) do
    submission = %__MODULE__{
      id: next_id(),
      author_username: author_username,
      title: title || "",
      subtitle: "",
      abstract: "",
      section: "Artikel Penelitian",
      keywords: "",
      language: "id",
      references: "",
      type: :article,
      status: :incomplete,
      stage: :submission,
      files: [],
      contributors: [],
      editors: [],
      editor_comments: "",
      comments_to_editor: "",
      discussions: [],
      editor_replies: [],
      checklist_agreed: false,
      privacy_consent: false,
      review: nil,
      created_at: DateTime.utc_now(),
      date_submitted: nil
    }

    Agent.update(__MODULE__, fn subs -> [submission | subs] end)
    submission
  end

  @doc """
  Update submission fields from params (string-keyed map).
  Only known fields are persisted; nil/blank values for required text are kept as-is
  unless explicitly provided.
  """
  def update(id, params) do
    id = normalize_id(id)
    current = get(id)

    if is_nil(current) do
      {:error, :not_found}
    else
      updated =
        current
        |> maybe_put(:title, params["title"])
        |> maybe_put(:subtitle, params["subtitle"])
        |> maybe_put(:abstract, params["abstract"])
        |> maybe_put(:section, params["section"])
        |> maybe_put(:keywords, params["keywords"])
        |> maybe_put(:language, params["language"])
        |> maybe_put(:references, params["references"])
        |> maybe_put_cleared(:editor_comments, params)
        |> maybe_put_cleared(:comments_to_editor, params)
        |> maybe_put_boolean(:checklist_agreed, params)
        |> maybe_put_boolean(:privacy_consent, params)
        |> maybe_put_files(params)
        |> maybe_put_list(:contributors, params["contributors"])
        |> maybe_put_stage(params)
        |> maybe_put_status(params)

      Agent.update(__MODULE__, fn subs ->
        Enum.map(subs, fn s -> if s.id == id, do: updated, else: s end)
      end)

      {:ok, updated}
    end
  end

  @doc """
  Update a single contributor (matched by id) with string-keyed fields.
  Setting `primary` to true clears the flag on every other contributor.
  """
  def update_contributor(id, contributor_id, fields) when is_map(fields) do
    id = normalize_id(id)
    contributor_id = normalize_id(contributor_id)
    current = get(id)

    if is_nil(current) do
      {:error, :not_found}
    else
      primary = fields["primary"] in ["true", "on", "1"]
      normalized = normalize_contributor_fields(fields)
      existing = Enum.any?(current.contributors || [], &(&1.id == contributor_id))

      contributors =
        cond do
          existing ->
            Enum.map(current.contributors || [], fn c ->
              cond do
                c.id == contributor_id ->
                  Map.merge(c, normalized)

                primary ->
                  %{c | primary: false}

                true ->
                  c
              end
            end)

          true ->
            new_contributor = Map.merge(%{id: contributor_id}, normalized)

            [
              new_contributor
              | Enum.map(current.contributors || [], fn c ->
                  if primary, do: %{c | primary: false}, else: c
                end)
            ]
        end

      Agent.update(__MODULE__, fn subs ->
        Enum.map(subs, fn s -> if s.id == id, do: %{s | contributors: contributors}, else: s end)
      end)

      {:ok, %{current | contributors: contributors}}
    end
  end

  @doc """
  Rename a single submission file (matched by its id, falling back to its
  1-based position in the list) to a non-blank name.
  """
  def rename_file(id, file_id, new_name) do
    id = normalize_id(id)
    file_id = normalize_id(file_id)
    current = get(id)

    cond do
      is_nil(current) ->
        {:error, :not_found}

      new_name in [nil, ""] ->
        {:error, :invalid_name}

      true ->
        files =
          (current.files || [])
          |> Enum.with_index(1)
          |> Enum.map(fn {file, idx} ->
            if file[:id] == file_id or idx == file_id do
              Map.put(file, :filename, new_name)
            else
              file
            end
          end)

        updated = %{current | files: files}

        Agent.update(__MODULE__, fn subs ->
          Enum.map(subs, fn s -> if s.id == id, do: updated, else: s end)
        end)

        {:ok, updated}
    end
  end

  @doc """
  Set a single contributor (matched by id) as the primary contact, clearing
  the primary flag on every other contributor.
  """
  def set_primary_contact(id, contributor_id) do
    id = normalize_id(id)
    contributor_id = normalize_id(contributor_id)
    current = get(id)

    if is_nil(current) || !Enum.any?(current.contributors || [], &(&1.id == contributor_id)) do
      {:error, :not_found}
    else
      contributors =
        Enum.map(current.contributors || [], fn c ->
          %{c | primary: c.id == contributor_id}
        end)

      Agent.update(__MODULE__, fn subs ->
        Enum.map(subs, fn s -> if s.id == id, do: %{s | contributors: contributors}, else: s end)
      end)

      {:ok, %{current | contributors: contributors}}
    end
  end

  @doc """
  Remove a single contributor (matched by id) from a submission.
  """
  def delete_contributor(id, contributor_id) do
    id = normalize_id(id)
    contributor_id = normalize_id(contributor_id)
    current = get(id)

    if is_nil(current) do
      {:error, :not_found}
    else
      contributors = Enum.reject(current.contributors || [], &(&1.id == contributor_id))

      Agent.update(__MODULE__, fn subs ->
        Enum.map(subs, fn s -> if s.id == id, do: %{s | contributors: contributors}, else: s end)
      end)

      {:ok, %{current | contributors: contributors}}
    end
  end

  @doc """
  Move a single contributor (matched by id) up or down in the list order.
  `dir` is `"up"` or `"down"`.
  """
  def move_contributor(id, contributor_id, dir) do
    id = normalize_id(id)
    contributor_id = normalize_id(contributor_id)
    current = get(id)

    if is_nil(current) do
      {:error, :not_found}
    else
      contributors = current.contributors || []
      index = Enum.find_index(contributors, &(&1.id == contributor_id))

      if is_nil(index) do
        {:ok, current}
      else
        swap_index =
          case dir do
            "up" when index > 0 -> index - 1
            "down" when index < length(contributors) - 1 -> index + 1
            _ -> index
          end

        contributors =
          if swap_index == index do
            contributors
          else
            List.replace_at(contributors, index, Enum.at(contributors, swap_index))
            |> List.replace_at(swap_index, Enum.at(contributors, index))
          end

        Agent.update(__MODULE__, fn subs ->
          Enum.map(subs, fn s ->
            if s.id == id, do: %{s | contributors: contributors}, else: s
          end)
        end)

        {:ok, %{current | contributors: contributors}}
      end
    end
  end

  @doc """
  Set/clear a status atom on a submission (used by the author workflow).
  """
  def set_status(id, status)
      when status in [
             :active,
             :revisions_requested,
             :revisions_submitted,
             :incomplete,
             :scheduled,
             :published,
             :declined
           ] do
    id = normalize_id(id)
    current = get(id)

    if is_nil(current) do
      {:error, :not_found}
    else
      now = DateTime.utc_now()
      submitted = current.date_submitted || now
      stage = stage_for_status(status)

      updated =
        if status == :active do
          %{current | status: status, stage: stage, date_submitted: submitted}
        else
          %{current | status: status, stage: stage}
        end

      Agent.update(__MODULE__, fn subs ->
        Enum.map(subs, fn s -> if s.id == id, do: updated, else: s end)
      end)

      {:ok, updated}
    end
  end

  @doc """
  Seed data covering every workflow status so dashboards look realistic.
  """
  def seed do
    [
      %__MODULE__{
        id: 14,
        author_username: "author1",
        title: "Deteksi Berita Palsu pada Media Sosial Menggunakan Transformer",
        subtitle: "Studi Komparasi BERT dan GPT terhadap Korpora Bahasa Indonesia",
        abstract:
          "Penelitian ini mengembangkan model klasifikasi berbasis arsitektur Transformer untuk mendeteksi berita palsu pada media sosial berbahasa Indonesia. Model BERT yang disetel pada korpora sebesar 120.000 dokumen mencapai akurasi 94,7%, mengungguli pendekatan baseline berbasis TF-IDF dan Word2Vec. Hasil menunjukkan bahwa representasi kontekstual berperan penting dalam menangkap pola kebahasaan indikatif.",
        section: "Artikel Penelitian",
        keywords: "berita palsu, transformer, BERT, NLP, deteksi informasi",
        language: "id",
        references:
          "1. Vaswani, A., et al. (2017). Attention is all you need. NeurIPS.\n2. Devlin, J., et al. (2019). BERT: Pre-training of deep bidirectional transformers. NAACL.\n3. Maas, A., et al. (2011). Learning word vectors for sentiment analysis. ACL.",
        type: :article,
        status: :active,
        stage: :initial_review,
        checklist_agreed: true,
        privacy_consent: true,
        comments_to_editor: "",
        files: [
          %{
            id: 1,
            filename: "manuscript.pdf",
            type: "application/pdf",
            size: "1.4 MB",
            date: "2026-08-11",
            genre: "Manuscript",
            has_revisions: false
          },
          %{
            id: 2,
            filename: "dataset-berita.csv",
            type: "text/csv",
            size: "3.2 MB",
            date: "2026-08-10",
            genre: "Research Instrument",
            has_revisions: false
          }
        ],
        contributors: [
          %{
            id: 1,
            given_name: "Ahmad",
            family_name: "Fauzi",
            email: "author1@informatika.ac.id",
            affiliation: "Universitas Teknologi",
            country: "Indonesia",
            role: :author,
            primary: true
          },
          %{
            id: 2,
            given_name: "Dewi",
            family_name: "Lestari",
            email: "dewi@universitas.ac.id",
            affiliation: "Universitas Teknologi",
            country: "Indonesia",
            role: :author,
            primary: false
          }
        ],
        editors: [%{id: 1, name: "Prof. Budi Santoso", email: "editor@test.com", role: "Editor"}],
        review: %{
          round: 1,
          status: :in_review,
          summary: "Sedang dalam proses tinjauan oleh reviewer.",
          assignments: [
            %{name: "Dr. Bambang Wijaya", recommendation: "In Progress", date: "2026-08-12"}
          ]
        },
        created_at: ~U[2026-08-10 09:30:00Z],
        date_submitted: ~U[2026-08-11 10:00:00Z]
      },
      %__MODULE__{
        id: 11,
        author_username: "author1",
        title: "Penerapan Deep Learning untuk Deteksi Penyakit Tanaman",
        subtitle: "Studi kasus berbasis Citra Multispektral",
        abstract:
          "Penelitian ini mengembangkan model deep learning berbasis Convolutional Neural Network untuk mendeteksi penyakit tanaman secara otomatis dari citra multispektral. Model yang diusulkan mencapai akurasi 97,2% pada set data uji. Hasil penelitian menunjukkan bahwa pendekatan ini dapat membantu petani melakukan deteksi dini dan mengurangi kerugian hasil panen.",
        section: "Artikel Penelitian",
        keywords:
          "deep learning, convolutional neural network, citra multispektral, deteksi penyakit",
        language: "id",
        type: :article,
        status: :published,
        stage: :production,
        checklist_agreed: true,
        privacy_consent: true,
        comments_to_editor: "",
        files: [
          %{
            id: 1,
            filename: "manuscript-final.pdf",
            type: "application/pdf",
            size: "1.2 MB",
            date: "2026-07-14",
            genre: "Manuscript",
            has_revisions: false
          },
          %{
            id: 2,
            filename: "gambar-tabel.docx",
            type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            size: "845 KB",
            date: "2026-07-14",
            genre: "Research Instrument",
            has_revisions: false
          }
        ],
        contributors: [
          %{
            id: 1,
            given_name: "Ahmad",
            family_name: "Fauzi",
            email: "author1@informatika.ac.id",
            affiliation: "Universitas Teknologi",
            country: "Indonesia",
            role: :author,
            primary: true
          },
          %{
            id: 2,
            given_name: "Siti",
            family_name: "Rahmawati",
            email: "siti@universitas.ac.id",
            affiliation: "Universitas Teknologi",
            country: "Indonesia",
            role: :author
          }
        ],
        editors: [
          %{id: 1, name: "Prof. Budi Santoso", email: "editor@test.com", role: "Editor"}
        ],
        review: %{
          round: 2,
          status: :accepted,
          summary: "Diterima dengan perbaikan minor pada revisi ke-2.",
          assignments: [
            %{name: "Dr. Siti Nurhaliza", recommendation: "Accept", date: "2026-06-01"},
            %{name: "Dr. Bambang Wijaya", recommendation: "Accept", date: "2026-06-10"}
          ]
        },
        created_at: ~U[2026-03-01 08:00:00Z],
        date_submitted: ~U[2026-03-05 08:00:00Z]
      },
      %__MODULE__{
        id: 10,
        author_username: "author1",
        title: "Optimasi Algoritma Genetika pada Penjadwalan Produksi",
        subtitle: "Perbandingan dengan Metode Simulated Annealing",
        abstract:
          "Makalah ini mengevaluasi performa algoritma genetika yang dioptimasi untuk masalah penjadwalan produksi job-shop dibandingkan dengan simulated annealing. Eksperimen dilakukan pada 20 instance benchmark. Algoritma genetika menunjukkan makespan lebih rendah pada 15 dari 20 instance.",
        section: "Artikel Penelitian",
        keywords: "algoritma genetika, simulated annealing, penjadwalan, optimasi",
        language: "id",
        type: :article,
        status: :scheduled,
        stage: :production,
        checklist_agreed: true,
        privacy_consent: true,
        comments_to_editor: "",
        files: [
          %{
            id: 1,
            filename: "manuscript-rev2.pdf",
            type: "application/pdf",
            size: "980 KB",
            date: "2026-08-01",
            genre: "Manuscript",
            has_revisions: true
          }
        ],
        contributors: [
          %{
            id: 1,
            given_name: "Ahmad",
            family_name: "Fauzi",
            email: "author1@informatika.ac.id",
            affiliation: "Universitas Teknologi",
            country: "Indonesia",
            role: :author,
            primary: true
          }
        ],
        editors: [
          %{id: 1, name: "Prof. Budi Santoso", email: "editor@test.com", role: "Editor"},
          %{id: 2, name: "Dr. Siti Nurhaliza", email: "reviewer@test.com", role: "Reviewer"}
        ],
        review: %{
          round: 1,
          status: :accepted,
          summary: "Jadwal terbit: Volume 9, Nomor 2.",
          assignments: []
        },
        created_at: ~U[2026-04-12 08:00:00Z],
        date_submitted: ~U[2026-04-15 08:00:00Z]
      },
      %__MODULE__{
        id: 9,
        author_username: "author1",
        title: "Sistem Rekomendasi E-Learning Berbasis Collaborative Filtering",
        subtitle: "",
        abstract:
          "Sebuah sistem rekomendasi untuk platform e-learning dikembangkan menggunakan collaborative filtering dan matrix factorization untuk memberikan rekomendasi materi pembelajaran personal.",
        section: "Artikel Penelitian",
        keywords: "rekomendasi, collaborative filtering, e-learning",
        language: "id",
        type: :article,
        status: :revisions_submitted,
        stage: :external_review,
        checklist_agreed: true,
        privacy_consent: true,
        comments_to_editor: "",
        files: [
          %{
            id: 1,
            filename: "manuscript-rev1.pdf",
            type: "application/pdf",
            size: "1.0 MB",
            date: "2026-08-05",
            genre: "Manuscript",
            has_revisions: true
          }
        ],
        contributors: [
          %{
            id: 1,
            given_name: "Ahmad",
            family_name: "Fauzi",
            email: "author1@informatika.ac.id",
            affiliation: "Universitas Teknologi",
            country: "Indonesia",
            role: :author,
            primary: true
          }
        ],
        editors: [%{id: 1, name: "Prof. Budi Santoso", email: "editor@test.com", role: "Editor"}],
        review: %{
          round: 1,
          status: :revision_submitted,
          summary: "Revisi telah dikirim dan menunggu pengecekan editor.",
          assignments: []
        },
        created_at: ~U[2026-05-02 08:00:00Z],
        date_submitted: ~U[2026-05-04 08:00:00Z]
      },
      %__MODULE__{
        id: 8,
        author_username: "author1",
        title: "Analisis Sentimen Media Sosial Menggunakan Long Short-Term Memory",
        subtitle: "",
        abstract:
          "Penelitian ini menggunakan LSTM untuk menganalisis sentimen pada media sosial berbahasa Indonesia. Dataset diambil dari Twitter dengan total 50.000 tweet.",
        section: "Artikel Penelitian",
        keywords: "sentimen, LSTM, media sosial, NLP",
        language: "id",
        type: :article,
        status: :revisions_requested,
        stage: :external_review,
        checklist_agreed: true,
        privacy_consent: true,
        comments_to_editor: "",
        files: [
          %{
            id: 1,
            filename: "manuscript.pdf",
            type: "application/pdf",
            size: "1.4 MB",
            date: "2026-07-20",
            genre: "Manuscript",
            has_revisions: false
          }
        ],
        contributors: [
          %{
            id: 1,
            given_name: "Ahmad",
            family_name: "Fauzi",
            email: "author1@informatika.ac.id",
            affiliation: "Universitas Teknologi",
            country: "Indonesia",
            role: :author,
            primary: true
          }
        ],
        editors: [%{id: 1, name: "Prof. Budi Santoso", email: "editor@test.com", role: "Editor"}],
        review: %{
          round: 1,
          status: :revision_requested,
          summary: "Perlu revisi: perbaiki metodologi dan tambahkan analisis error.",
          assignments: []
        },
        created_at: ~U[2026-06-10 08:00:00Z],
        date_submitted: ~U[2026-06-12 08:00:00Z]
      },
      %__MODULE__{
        id: 7,
        author_username: "author1",
        title: "Integrasi IoT untuk Monitoring Kualitas Udara Berbasis LoRa",
        subtitle: "",
        abstract:
          "Makalah ini mengimplementasikan jaringan sensor IoT menggunakan LoRa untuk memantau kualitas udara secara real-time pada area kampus.",
        section: "Tinjauan Literatur",
        keywords: "IoT, LoRa, monitoring, kualitas udara",
        language: "id",
        type: :article,
        status: :active,
        stage: :initial_review,
        checklist_agreed: true,
        privacy_consent: true,
        comments_to_editor: "",
        files: [
          %{
            id: 1,
            filename: "manuscript.pdf",
            type: "application/pdf",
            size: "1.1 MB",
            date: "2026-08-08",
            genre: "Manuscript",
            has_revisions: false
          }
        ],
        contributors: [
          %{
            id: 1,
            given_name: "Ahmad",
            family_name: "Fauzi",
            email: "author1@informatika.ac.id",
            affiliation: "Universitas Teknologi",
            country: "Indonesia",
            role: :author,
            primary: true
          }
        ],
        editors: [],
        review: %{
          round: 1,
          status: :in_review,
          summary: "Sedang dalam proses tinjauan.",
          assignments: []
        },
        created_at: ~U[2026-08-08 08:00:00Z],
        date_submitted: ~U[2026-08-08 08:00:00Z]
      },
      %__MODULE__{
        id: 6,
        author_username: "author",
        title: "Studi Awal Implementasi Blockchain pada Sistem Pencatatan Akademik",
        subtitle: "Prototype dan Evaluasi",
        abstract:
          "Penelitian pendahuluan ini mengeksplorasi penggunaan teknologi blockchain untuk sistem pencatatan transkrip akademik yang transparan dan anti-manipulasi.",
        section: "Artikel Penelitian",
        keywords: "blockchain, akademik, transparansi",
        language: "id",
        type: :article,
        status: :declined,
        stage: :external_review,
        checklist_agreed: true,
        privacy_consent: true,
        comments_to_editor: "",
        files: [
          %{
            id: 1,
            filename: "manuscript.pdf",
            type: "application/pdf",
            size: "890 KB",
            date: "2026-05-18",
            genre: "Manuscript",
            has_revisions: false
          }
        ],
        contributors: [
          %{
            id: 1,
            given_name: "Test",
            family_name: "Author",
            email: "author@test.com",
            affiliation: "Test University",
            country: "Indonesia",
            role: :author,
            primary: true
          }
        ],
        editors: [%{id: 1, name: "Prof. Budi Santoso", email: "editor@test.com", role: "Editor"}],
        review: %{
          round: 1,
          status: :declined,
          summary: "Tidak sesuai dengan cakupan jurnal.",
          assignments: []
        },
        created_at: ~U[2026-05-18 08:00:00Z],
        date_submitted: ~U[2026-05-20 08:00:00Z]
      },
      %__MODULE__{
        id: 5,
        author_username: "author1",
        title: "Rancang Bangun Aplikasi Mobile Peta Digital Kampus",
        subtitle: "",
        abstract: "",
        section: "Artikel Penelitian",
        keywords: "",
        language: "id",
        type: :article,
        status: :incomplete,
        stage: :submission,
        checklist_agreed: false,
        privacy_consent: false,
        comments_to_editor: "",
        files: [],
        contributors: [],
        editors: [],
        review: nil,
        created_at: ~U[2026-08-10 08:00:00Z],
        date_submitted: nil
      }
    ]
  end

  defp next_id do
    Agent.get(__MODULE__, fn subs ->
      Enum.reduce(subs, 0, fn s, acc -> max(s.id, acc) end) + 1
    end)
  end

  defp normalize_id(id) when is_integer(id), do: id

  defp normalize_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> int
      :error -> id
    end
  end

  defp normalize_id(id), do: id

  defp next_discussion_id([]), do: 1
  defp next_discussion_id(nil), do: 1

  defp next_discussion_id(discussions) do
    (discussions |> Enum.map(& &1.id) |> Enum.max()) + 1
  end

  defp maybe_put(current, _key, value) when value in [nil, ""], do: current
  defp maybe_put(current, key, value), do: Map.put(current, key, value)

  defp maybe_put_cleared(current, key, params) do
    if Map.has_key?(params, "#{key}") do
      Map.put(current, key, params["#{key}"] || "")
    else
      current
    end
  end

  defp maybe_put_list(current, _key, value) when not is_list(value), do: current
  defp maybe_put_list(current, key, value), do: Map.put(current, key, value)

  # Files arrive as a JSON string produced by the upload UI ("files_json").
  defp maybe_put_files(current, %{"files" => files}) when is_list(files),
    do: Map.put(current, :files, normalize_files(files))

  defp maybe_put_files(current, %{"files_json" => json}) when is_binary(json) and json != "" do
    case Jason.decode(json) do
      {:ok, files} when is_list(files) -> Map.put(current, :files, normalize_files(files))
      _ -> current
    end
  end

  defp maybe_put_files(current, _params), do: current

  defp normalize_files(files) do
    files
    |> Enum.with_index(1)
    |> Enum.map(fn {file, index} ->
      %{
        id: index,
        filename: file_field(file, :filename),
        size: file_field(file, :size),
        date: file_field(file, :date),
        genre: file_field(file, :genre)
      }
    end)
  end

  defp file_field(file, key) when is_map(file) do
    Map.get(file, key) || Map.get(file, Atom.to_string(key)) || ""
  end

  defp file_field(_file, _key), do: ""

  defp normalize_contributor_fields(fields) do
    %{
      given_name: blank_to_nil(fields["given_name"]),
      family_name: blank_to_nil(fields["family_name"]),
      preferred_public_name: blank_to_nil(fields["preferred_public_name"]),
      email: blank_to_nil(fields["email"]),
      country: blank_to_nil(fields["country"]),
      bio_statement: blank_to_nil(fields["bio_statement"]),
      affiliation: blank_to_nil(fields["affiliation"]),
      role: normalize_role(fields["role"]),
      primary: checkbox_value?(fields["primary"]),
      public_list: checkbox_value?(fields["public_list"])
    }
  end

  defp checkbox_value?(value) when is_list(value),
    do: Enum.any?(value, &(&1 in ["true", "on", "1"]))

  defp checkbox_value?(value), do: value in ["true", "on", "1"]

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  defp normalize_role(role) when role in ["author", "translator", "cover_designer"],
    do: String.to_atom(role)

  defp normalize_role("Author"), do: :author
  defp normalize_role("Translator"), do: :translator
  defp normalize_role("Cover Designer"), do: :cover_designer
  defp normalize_role(_), do: :author

  defp maybe_put_status(current, params) do
    cond do
      params["submit_to_journal"] in ["1", "true"] ->
        %{current | status: :active, stage: :initial_review}

      params["save_status"] == "complete" ->
        %{current | status: :active, stage: :initial_review}

      true ->
        current
    end
  end

  defp maybe_put_boolean(current, _key, nil), do: current

  defp maybe_put_boolean(current, key, value) when value in [true, "1", "true", "on"],
    do: Map.put(current, key, true)

  defp maybe_put_boolean(current, key, _value), do: Map.put(current, key, false)

  defp maybe_put_stage(current, params) do
    case params["stage"] do
      stage when is_binary(stage) and stage != "" ->
        Map.put(current, :stage, String.to_existing_atom(stage))

      _ ->
        current
    end
  end

  @doc """
  Assign an editor to a submission. Adds the editor to the editors list.
  """
  def assign_editor(id, editor_info) do
    id = normalize_id(id)
    current = get(id)

    if is_nil(current) do
      {:error, :not_found}
    else
      editors = (current.editors || []) ++ [editor_info]
      updated = %{current | editors: editors}

      Agent.update(__MODULE__, fn subs ->
        Enum.map(subs, fn s -> if s.id == id, do: updated, else: s end)
      end)

      {:ok, updated}
    end
  end

  @doc """
  Add an editor pre-review discussion thread to a submission
  (Pre-Review Discussions panel).
  """
  def add_discussion(id, params) do
    id = normalize_id(id)
    current = get(id)

    if is_nil(current) do
      {:error, :not_found}
    else
      discussion = %{
        id: next_discussion_id(Map.get(current, :discussions)),
        subject: params["subject"] || "Discussion",
        message: params["message"] || "",
        author: params["author"] || "Editor",
        date: Date.to_string(Date.utc_today()),
        replies: []
      }

      discussions = (Map.get(current, :discussions) || []) ++ [discussion]
      updated = Map.put(current, :discussions, discussions)

      Agent.update(__MODULE__, fn subs ->
        Enum.map(subs, fn s -> if s.id == id, do: updated, else: s end)
      end)

      {:ok, updated}
    end
  end

  @doc """
  Add a reply message to the submission's "Comment for the Editor" thread.
  """
  def add_editor_reply(id, author, message) do
    id = normalize_id(id)
    current = get(id)

    if is_nil(current) do
      {:error, :not_found}
    else
      now = DateTime.utc_now()

      reply = %{
        author: author || "Author",
        message: message || "",
        date: Calendar.strftime(now, "%Y-%m-%d %H:%M")
      }

      replies = (Map.get(current, :editor_replies) || []) ++ [reply]
      updated = Map.put(current, :editor_replies, replies)

      Agent.update(__MODULE__, fn subs ->
        Enum.map(subs, fn s -> if s.id == id, do: updated, else: s end)
      end)

      {:ok, updated}
    end
  end

  @doc """
  Set the workflow stage for a submission.
  """
  def set_stage(id, stage) when is_atom(stage) do
    id = normalize_id(id)
    current = get(id)

    if is_nil(current) do
      {:error, :not_found}
    else
      updated = %{current | stage: stage}

      Agent.update(__MODULE__, fn subs ->
        Enum.map(subs, fn s -> if s.id == id, do: updated, else: s end)
      end)

      {:ok, updated}
    end
  end

  defp stage_for_status(:active), do: :initial_review
  defp stage_for_status(:revisions_requested), do: :external_review
  defp stage_for_status(:revisions_submitted), do: :external_review
  defp stage_for_status(:scheduled), do: :production
  defp stage_for_status(:published), do: :production
  defp stage_for_status(:declined), do: :external_review
  defp stage_for_status(:incomplete), do: :submission
  defp stage_for_status(_), do: :submission
end
