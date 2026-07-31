defmodule OjsLanding.Journal do
  defstruct [:id, :title, :description, :issn, :publisher, :editor, :articles, :path]

  def all do
    [
      %__MODULE__{
        id: 1,
        title: "Informatika",
        description: "deskripsi",
        issn: "1234-5678",
        publisher: "Universitas Teknologi",
        editor: "Dr. Ahmad Santoso",
        path: "informatika",
        articles: []
      },
      %__MODULE__{
        id: 2,
        title: "Jurnal Perang Dunia 1",
        description: "Ini jurnal membahas tentang Perang Dunia ke 1",
        issn: "2580-1234",
        publisher: "Pusat Studi Sejarah Universitas Indonesia",
        editor: "Prof. Dr. Bambang Wijaya, M.Hum",
        path: "JPD",
        articles: [
          %{
            id: 1,
            title: "Penyebab Utama Perang Dunia Pertama",
            authors: ["Dr. Siti Nurhaliza", "Ahmad Fauzi"],
            abstract: "Artikel ini membahas tentang faktor-faktor yang menyebabkan terjadinya Perang Dunia Pertama, termasuk nasionalisme, imperialisme, dan sistem aliansi.",
            pages: "1-15",
            published_date: "2024-01-15"
          },
          %{
            id: 2,
            title: "Pertempuran Verdun: Analisis Strategis",
            authors: ["Prof. Budi Setiawan"],
            abstract: "Analisis mendalam tentang Pertempuran Verdun yang berlangsung dari Februari hingga Desember 1916, salah satu pertempuran terpanjang dan paling berdarah dalam sejarah.",
            pages: "16-35",
            published_date: "2024-01-15"
          },
          %{
            id: 3,
            title: "Dampak Sosial Perang Dunia I di Eropa",
            authors: ["Dr. Dewi Lestari", "Rudi Hartono", "Maya Sari"],
            abstract: "Penelitian ini mengkaji dampak sosial yang ditimbulkan oleh Perang Dunia I terhadap masyarakat Eropa, termasuk perubahan struktur sosial dan peran wanita.",
            pages: "36-52",
            published_date: "2024-01-15"
          },
          %{
            id: 4,
            title: "Teknologi Militer dalam Perang Dunia Pertama",
            authors: ["Ir. Hendra Gunawan, M.T"],
            abstract: "Pembahasan tentang perkembangan teknologi militer yang digunakan dalam Perang Dunia I, termasuk tank, pesawat terbang, dan senjata kimia.",
            pages: "53-68",
            published_date: "2024-01-15"
          }
        ]
      }
    ]
  end

  def get!(id) do
    Enum.find(all(), fn journal -> journal.id == id end)
  end
end
