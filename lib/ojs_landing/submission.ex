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
    :type,
    :status,
    :files,
    :contributors,
    :editors,
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
      type: :article,
      status: :incomplete,
      files: [],
      contributors: [],
      editors: [],
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
        |> maybe_put_status(params)

      Agent.update(__MODULE__, fn subs ->
        Enum.map(subs, fn s -> if s.id == id, do: updated, else: s end)
      end)

      {:ok, updated}
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

      updated =
        if status == :active do
          %{current | status: status, date_submitted: submitted}
        else
          %{current | status: status}
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
        type: :article,
        status: :active,
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

  defp maybe_put(current, _key, value) when value in [nil, ""], do: current
  defp maybe_put(current, key, value), do: Map.put(current, key, value)

  defp maybe_put_status(current, params) do
    cond do
      params["submit_to_journal"] in ["1", "true"] -> %{current | status: :active}
      params["save_status"] == "complete" -> %{current | status: :active}
      true -> current
    end
  end
end
