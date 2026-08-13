defmodule OjsLandingWeb.DoiArticleControllerTest do
  use OjsLandingWeb.ConnCase

  describe "authentication & role access" do
    test "redirects to login when not authenticated" do
      conn = get(build_conn(), "/dashboard/doiArticles")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Akses ditolak"
    end

    test "redirects non-admin non-editor users away from the page" do
      conn =
        build_conn()
        |> login_as("author1")
        |> get("/dashboard/doiArticles")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Hanya admin atau editor"
    end

    test "allows editor users to open the page" do
      conn =
        build_conn()
        |> login_as("editor")
        |> get("/dashboard/doiArticles")

      html = html_response(conn, 200)
      assert html =~ "DOI Artikel"
      assert html =~ "Artikel"
    end

    test "allows admin users to open the page" do
      conn =
        build_conn()
        |> login_as("alief")
        |> get("/dashboard/doiArticles")

      assert html_response(conn, 200) =~ "DOI Artikel"
    end
  end

  describe "GET /dashboard/doiArticles" do
    test "renders the DOI prefix warning bar" do
      conn = editor_get("/dashboard/doiArticles")
      html = html_response(conn, 200)

      assert html =~
               "DOI tidak dapat dibuat kecuali jika anda menyediakan prefiks DOI yang dibuat."
    end

    test "renders the article list with IDs and titles" do
      conn = editor_get("/dashboard/doiArticles")
      html = html_response(conn, 200)

      assert html =~ "pico — the 100 cara gitu lah: biar apa biarin"
      assert html =~ "Faiha1 — The kucingkelinci"
      assert html =~ ~s(id="doi-article-row-6")
      assert html =~ ~s(id="doi-article-row-1")
    end

    test "renders filter groups with Status, Pendaftaran and Terbitan" do
      conn = editor_get("/dashboard/doiArticles")
      html = html_response(conn, 200)

      assert html =~ "Membutuhkan DOI"
      assert html =~ "DOI Ditetapkan"
      assert html =~ "Tidak terdaftar"
      assert html =~ "Dikirimkan"
      assert html =~ "Didaftarkan"
      assert html =~ "Terdapat Eror"
      assert html =~ "Membutuhkan Sinkronisasi"
      assert html =~ "Terbitan"
    end

    test "renders the sidebar with DOI submenu items" do
      conn = editor_get("/dashboard/doiArticles")
      html = html_response(conn, 200)

      assert html =~ "Dasbor Editor"
      assert html =~ "Terbitan"
      assert html =~ "Pengaturan"
      assert html =~ "Statistik"
      assert html =~ "Perangkat"
      assert html =~ "Administrasi"
    end

    test "renders bulk actions button and search box" do
      conn = editor_get("/dashboard/doiArticles")
      html = html_response(conn, 200)

      assert html =~ "Tindakan Massal"
      assert html =~ "Cari"
    end
  end

  defp login_as(conn, username) do
    init_test_session(conn, current_user: username)
  end

  defp editor_get(path) do
    build_conn()
    |> login_as("editor")
    |> get(path)
  end
end
