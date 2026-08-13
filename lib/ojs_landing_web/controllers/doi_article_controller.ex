defmodule OjsLandingWeb.DoiArticleController do
  use OjsLandingWeb, :controller
  plug OjsLandingWeb.Plugs.Auth, :require_editor_admin

  def index(conn, _params) do
    user = conn.assigns.current_user
    articles = get_articles()

    conn
    |> put_root_layout(false)
    |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
    |> render(:index,
      user: user,
      articles: articles,
      status_counts: status_counts(articles),
      registration_counts: registration_counts(articles),
      page_title: "DOI Artikel"
    )
  end

  defp get_articles do
    [
      %{
        id: 6,
        title: "pico — the 100 cara gitu lah: biar apa biarin",
        doi: nil,
        status: :needs_doi,
        published: false
      },
      %{
        id: 1,
        title: "Faiha1 — The kucingkelinci",
        doi: nil,
        status: :needs_doi,
        published: false
      },
      %{
        id: 2,
        title: "Analisis Keamanan Jaringan Menggunakan Metode Penetration Testing",
        doi: "10.1234/informatika.v1i1.2",
        status: :registered,
        published: true
      },
      %{
        id: 3,
        title: "Implementasi Machine Learning untuk Prediksi Penyakit Jantung",
        doi: "10.1234/informatika.v1i1.3",
        status: :submitted,
        published: true
      },
      %{
        id: 4,
        title: "Pengembangan Aplikasi Mobile Berbasis Flutter untuk Manajemen Inventori",
        doi: nil,
        status: :assigned,
        published: true
      },
      %{
        id: 5,
        title: "Rancang Bangun Aplikasi Mobile Peta Digital Kampus",
        doi: nil,
        status: :error,
        published: false
      }
    ]
  end

  defp status_counts(articles) do
    %{
      needs_doi: Enum.count(articles, &(&1.status == :needs_doi)),
      assigned: Enum.count(articles, &(&1.status == :assigned))
    }
  end

  defp registration_counts(articles) do
    %{
      unregistered: Enum.count(articles, &(&1.status in [:needs_doi, :assigned, :unregistered])),
      submitted: Enum.count(articles, &(&1.status == :submitted)),
      registered: Enum.count(articles, &(&1.status == :registered)),
      error: Enum.count(articles, &(&1.status == :error)),
      stale: Enum.count(articles, &(&1.status == :stale))
    }
  end
end
