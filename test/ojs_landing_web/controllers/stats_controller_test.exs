defmodule OjsLandingWeb.StatsControllerTest do
  use OjsLandingWeb.ConnCase

  describe "authentication & role access" do
    test "redirects to login when not authenticated" do
      conn = get(build_conn(), "/kucingkelinci/stats/publications/publications")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Akses ditolak"
    end

    test "redirects non-admin non-editor users away from the page" do
      conn =
        build_conn()
        |> login_as("author1")
        |> get("/kucingkelinci/stats/publications/publications")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Hanya admin atau editor"
    end

    test "allows editor users to open the publications page" do
      conn = editor_get("/kucingkelinci/stats/publications/publications")

      html = html_response(conn, 200)
      assert html =~ "Publications"
      assert html =~ "Faiha1"
    end

    test "redirects unknown journal back home" do
      conn = editor_get("/nonexistent/stats/reports")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Journal not found"
    end
  end

  describe "GET stats pages" do
    test "renders publications report with chart and table" do
      conn = editor_get("/kucingkelinci/stats/publications/publications")
      html = html_response(conn, 200)

      assert html =~ "This report provides a summary of the views and downloads"
      assert html =~ "Export CSV"
      assert html =~ "Perbandingan Pola Tidur Kucing dan Kelinci"
      assert html =~ "Nutrisi Ideal untuk Kucing dan Kelinci"
      assert html =~ "stats-chart-bars"
    end

    test "renders issues report" do
      conn = editor_get("/kucingkelinci/stats/issues/issues")
      html = html_response(conn, 200)

      assert html =~ "Issues"
      assert html =~ "Vol. 1, No. 2 (2025)"
      assert html =~ "Vol. 1, No. 1 (2025)"
    end

    test "renders context report" do
      conn = editor_get("/kucingkelinci/stats/context/context")
      html = html_response(conn, 200)

      assert html =~ "Homepage"
      assert html =~ "Search Results"
    end

    test "renders editorial report with summary cards" do
      conn = editor_get("/kucingkelinci/stats/editorial/editorial")
      html = html_response(conn, 200)

      assert html =~ "Submissions Received"
      assert html =~ "Avg. Days to First Decision"
      assert html =~ "Days to Final Decision"
    end

    test "renders users report" do
      conn = editor_get("/kucingkelinci/stats/users/users")
      html = html_response(conn, 200)

      assert html =~ "Total Registered Users"
      assert html =~ "Administrator"
      assert html =~ "Journal Editor"
      assert html =~ "Reviewer"
      assert html =~ "Author"
    end

    test "renders COUNTER R5 report with TR tab by default" do
      conn = editor_get("/kucingkelinci/stats/counterR5/counterR5")
      html = html_response(conn, 200)

      assert html =~ "COUNTER R5"
      assert html =~ "Journal Report 1 (TR)"
      assert html =~ "Journal Report 1 (IR)"
      assert html =~ "Title Usage (TR)"
    end

    test "renders COUNTER R5 IR report when selected" do
      conn = editor_get("/kucingkelinci/stats/counterR5/counterR5?report=ir")
      html = html_response(conn, 200)

      assert html =~ "Item Usage (IR)"
    end

    test "renders reports index" do
      conn = editor_get("/kucingkelinci/stats/reports")
      html = html_response(conn, 200)

      assert html =~ "Article Views"
      assert html =~ "Editorial Activity"
      assert html =~ "COUNTER R5"
    end
  end

  describe "CSV export" do
    test "exports publications CSV" do
      conn = editor_get("/kucingkelinci/stats/publications/publications?export=csv")

      assert response(conn, 200) =~ "id,title,type,views,downloads"

      assert Enum.any?(conn.resp_headers, fn {k, v} ->
               k == "content-disposition" and v =~ ".csv"
             end)
    end

    test "exports editorial CSV" do
      conn = editor_get("/kucingkelinci/stats/editorial/editorial?export=csv")

      assert response(conn, 200) =~ "label,received,accepted,declined,published"
    end
  end

  describe "shared sidebar navigation" do
    test "renders the publications sidebar link" do
      conn = editor_get("/kucingkelinci/stats/users/users")
      html = html_response(conn, 200)

      assert html =~ "/kucingkelinci/stats/publications/publications"
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
