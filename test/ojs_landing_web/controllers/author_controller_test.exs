defmodule OjsLandingWeb.AuthorControllerTest do
  use OjsLandingWeb.ConnCase

  alias OjsLanding.Submission

  describe "authentication" do
    test "GET /submission/wizard/:id redirects to login when not authenticated" do
      conn = get(build_conn(), "/submission/wizard/14?tab=details")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "login"
    end
  end

  describe "submission wizard" do
    setup %{conn: conn} do
      {:ok, conn: init_test_session(conn, current_user: "author1")}
    end

    test "GET /submission/wizard/14?tab=details renders the details tab", %{conn: conn} do
      conn = get(conn, "/submission/wizard/14?tab=details")
      html = html_response(conn, 200)

      assert html =~ "Submission 14"
      assert html =~ "submission-details-form"
      assert html =~ "Deteksi Berita Palsu"
      assert html =~ "wizard-tab-files"
    end

    test "GET /submission/wizard/14 renders every workflow tab", %{conn: conn} do
      for {tab, needle} <- [
            {"details", "submission-details-form"},
            {"files", "submission-dropzone"},
            {"contributors", "btn-add-contributor"},
            {"editors", "btn-add-editor"},
            {"review", "btn-submit-journal"}
          ] do
        conn = get(conn, "/submission/wizard/14?tab=#{tab}")

        assert html_response(conn, 200) =~ needle,
               "expected tab #{tab} to render #{needle}"
      end
    end

    test "GET /submission/wizard/:id redirects to my submissions when not found", %{conn: conn} do
      conn = get(conn, "/submission/wizard/9999?tab=details")

      assert redirected_to(conn) == "/dashboard/mySubmissions"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "tidak ditemukan"
    end

    test "PUT /submission/wizard/:id saves the details form", %{conn: conn} do
      submission = Submission.create("author1")

      conn =
        put(
          conn,
          "/submission/wizard/#{submission.id}?tab=details",
          %{
            "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
            "submission" => %{"title" => "Judul Baru", "section" => "Studi Kasus"}
          }
        )

      assert redirected_to(conn) == "/submission/wizard/#{submission.id}?tab=details"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "berhasil disimpan"

      updated = Submission.get(submission.id)
      assert updated.title == "Judul Baru"
      assert updated.section == "Studi Kasus"
    end

    test "PUT /submission/wizard/:id submits to journal", %{conn: conn} do
      submission = Submission.create("author1")

      conn =
        put(
          conn,
          "/submission/wizard/#{submission.id}?tab=review",
          %{
            "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
            "submission" => %{"title" => "Judul Dikirim", "submit_to_journal" => "1"}
          }
        )

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "dikirim ke jurnal"
      assert Submission.get(submission.id).status == :active
    end
  end
end
