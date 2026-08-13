defmodule OjsLanding.Issue do
  @moduledoc """
  Journal issues (volume/number publications).

  Static seed data modeled after the `OjsLanding.Journal` module. Each issue
  belongs to a journal (via `journal_id`) and holds its own list of articles.
  """

  defstruct [
    :id,
    :journal_id,
    :title,
    :volume,
    :number,
    :year,
    :published_date,
    :status,
    :articles
  ]

  @doc """
  Get all issues (newest first by year/volume/number).
  """
  def all do
    seed()
    |> Enum.sort_by(&{&1.year || 0, &1.volume || 0, &1.number || 0}, :desc)
  end

  @doc """
  Get a single issue by id.
  """
  def get(id) when is_integer(id) do
    Enum.find(seed(), &(&1.id == id))
  end

  def get(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> get(int)
      :error -> nil
    end
  end

  @doc """
  Get a single issue by id, raising if not found.
  """
  def get!(id) do
    case get(id) do
      nil -> raise ArgumentError, "issue with id #{inspect(id)} not found"
      issue -> issue
    end
  end

  @doc """
  Get all issues belonging to a journal (newest first).
  """
  def for_journal(journal_id) do
    all()
    |> Enum.filter(&(&1.journal_id == journal_id))
  end

  @doc """
  Get the current (most recent published) issue for a journal.
  """
  def current(journal_id) do
    journal_id
    |> for_journal()
    |> Enum.find(&(&1.status == :published)) ||
      List.first(for_journal(journal_id))
  end

  defp seed do
    [
      %__MODULE__{
        id: 1,
        journal_id: 1,
        title: "Informatika: Volume 1",
        volume: 1,
        number: 1,
        year: 2024,
        published_date: "2024-03-30",
        status: :published,
        articles: []
      },
      %__MODULE__{
        id: 2,
        journal_id: 2,
        title: "Jurnal Perang Dunia 1: Volume 1, Nomor 1",
        volume: 1,
        number: 1,
        year: 2024,
        published_date: "2024-01-15",
        status: :published,
        articles: [
          %{
            id: 1,
            title: "Penyebab Utama Perang Dunia Pertama",
            authors: ["Dr. Siti Nurhaliza", "Ahmad Fauzi"],
            abstract:
              "Artikel ini membahas tentang faktor-faktor yang menyebabkan terjadinya Perang Dunia Pertama, termasuk nasionalisme, imperialisme, dan sistem aliansi.",
            pages: "1-15",
            published_date: "2024-01-15"
          },
          %{
            id: 2,
            title: "Pertempuran Verdun: Analisis Strategis",
            authors: ["Prof. Budi Setiawan"],
            abstract:
              "Analisis mendalam tentang Pertempuran Verdun yang berlangsung dari Februari hingga Desember 1916, salah satu pertempuran terpanjang dan paling berdarah dalam sejarah.",
            pages: "16-35",
            published_date: "2024-01-15"
          },
          %{
            id: 3,
            title: "Dampak Sosial Perang Dunia I di Eropa",
            authors: ["Dr. Dewi Lestari", "Rudi Hartono", "Maya Sari"],
            abstract:
              "Penelitian ini mengkaji dampak sosial yang ditimbulkan oleh Perang Dunia I terhadap masyarakat Eropa, termasuk perubahan struktur sosial dan peran wanita.",
            pages: "36-52",
            published_date: "2024-01-15"
          },
          %{
            id: 4,
            title: "Teknologi Militer dalam Perang Dunia Pertama",
            authors: ["Ir. Hendra Gunawan, M.T"],
            abstract:
              "Pembahasan tentang perkembangan teknologi militer yang digunakan dalam Perang Dunia I, termasuk tank, pesawat terbang, dan senjata kimia.",
            pages: "53-68",
            published_date: "2024-01-15"
          }
        ]
      },
      %__MODULE__{
        id: 3,
        journal_id: 2,
        title: "Jurnal Perang Dunia 1: Volume 2, Nomor 1",
        volume: 2,
        number: 1,
        year: 2025,
        published_date: "2025-06-20",
        status: :published,
        articles: [
          %{
            id: 5,
            title: "Diplomasi dan Pembentukan Aliansi Sebelum Perang Dunia Pertama",
            authors: ["Dr. Siti Nurhaliza"],
            abstract:
              "Kajian tentang bagaimana jaringan aliansi Eropa terbentuk melalui diplomasi rahasia dan dampaknya terhadap pecahnya konflik global pada tahun 1914.",
            pages: "1-18",
            published_date: "2025-06-20"
          },
          %{
            id: 6,
            title: "Peran Perempuan dalam Industri Perang di Eropa",
            authors: ["Maya Sari", "Prof. Budi Setiawan"],
            abstract:
              "Artikel ini menganalisis kontribusi perempuan dalam industri persenjataan dan sektor manufaktur selama Perang Dunia I serta perubahan status sosial yang dihasilkan.",
            pages: "19-33",
            published_date: "2025-06-20"
          }
        ]
      },
      %__MODULE__{
        id: 4,
        journal_id: 2,
        title: "Jurnal Perang Dunia 1: Volume 3, Nomor 1",
        volume: 3,
        number: 1,
        year: 2026,
        published_date: nil,
        status: :scheduled,
        articles: []
      },
      %__MODULE__{
        id: 5,
        journal_id: 3,
        title: "Kucing & Kelinci: Volume 1, Nomor 2",
        volume: 1,
        number: 2,
        year: 2025,
        published_date: "2025-06-15",
        status: :published,
        articles: []
      },
      %__MODULE__{
        id: 6,
        journal_id: 3,
        title: "Kucing & Kelinci: Volume 1, Nomor 1",
        volume: 1,
        number: 1,
        year: 2025,
        published_date: "2025-01-20",
        status: :published,
        articles: []
      }
    ]
  end
end
