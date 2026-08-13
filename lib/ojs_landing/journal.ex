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
        articles: [
          %{
            id: 1,
            title: "Sistem Rekomendasi Berbasis Collaborative Filtering untuk E-Learning",
            authors: ["Alief Rachman", "Dr. Siti Aminah"],
            abstract:
              "Penelitian ini mengembangkan sistem rekomendasi berbasis collaborative filtering untuk meningkatkan personalisasi pembelajaran pada platform e-learning.",
            pages: "1-12",
            published_date: "2024-06-10",
            doi: "10.1234/informatika.v1i1.1"
          },
          %{
            id: 2,
            title: "Analisis Keamanan Jaringan Menggunakan Metode Penetration Testing",
            authors: ["Budi Hartono", "Rina Wulandari"],
            abstract:
              "Studi ini menganalisis kerentanan keamanan jaringan melalui pendekatan penetration testing untuk mengidentifikasi celah keamanan pada infrastruktur TI.",
            pages: "13-27",
            published_date: "2024-06-10",
            doi: "10.1234/informatika.v1i1.2"
          },
          %{
            id: 3,
            title: "Implementasi Machine Learning untuk Prediksi Penyakit Jantung",
            authors: ["Dewi Kartika", "Agus Setiawan", "Maya Lestari"],
            abstract:
              "Penelitian menerapkan algoritma machine learning untuk memprediksi risiko penyakit jantung berdasarkan data klinis pasien dengan akurasi tinggi.",
            pages: "28-41",
            published_date: "2024-06-10",
            doi: "10.1234/informatika.v1i1.3"
          },
          %{
            id: 4,
            title: "Pengembangan Aplikasi Mobile Berbasis Flutter untuk Manajemen Inventori",
            authors: ["Eko Prasetyo", "Fitri Handayani"],
            abstract:
              "Artikel membahas pengembangan aplikasi manajemen inventori berbasis mobile menggunakan framework Flutter dengan arsitektur MVVM.",
            pages: "42-55",
            published_date: "2024-06-10",
            doi: "10.1234/informatika.v1i1.4"
          }
        ]
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
        title: "Kucing & Kelinci",
        description: "Jurnal yang membahas tentang kucing dan kelinci.",
        issn: "2715-2468",
        publisher: "Fakultas Kedokteran Hewan",
        editor: "Dr. Meong Banyak",
        path: "kucingkelinci",
        articles: [
          %{
            id: 1,
            title: "Faiha1 — The kucingkelinci",
            authors: ["Faiha", "Kucing Kelinci"],
            abstract:
              "Studi tentang perilaku kucing dan kelinci yang hidup berdampingan dalam satu rumah.",
            pages: "1-10",
            published_date: "2025-01-20",
            doi: "10.1234/kucingkelinci.v1i1.1"
          },
          %{
            id: 2,
            title: "Perbandingan Pola Tidur Kucing dan Kelinci",
            authors: ["Faiha", "Bella"],
            abstract:
              "Artikel ini membandingkan siklus tidur kucing domestik dengan kelinci peliharaan.",
            pages: "11-25",
            published_date: "2025-01-20",
            doi: "10.1234/kucingkelinci.v1i1.2"
          },
          %{
            id: 3,
            title: "Nutrisi Ideal untuk Kucing dan Kelinci",
            authors: ["Faiha", "Kucing Kelinci"],
            abstract:
              "Pembahasan tentang kebutuhan nutrisi harian kucing dan kelinci peliharaan.",
            pages: "26-40",
            published_date: "2025-06-15",
            doi: "10.1234/kucingkelinci.v1i2.3"
          }
        ]
      }
    ]
  end

  def get!(id) do
    Enum.find(all(), fn journal -> journal.id == id end)
  end
end
