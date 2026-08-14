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

  describe "start a new submission" do
    setup %{conn: conn} do
      {:ok, conn: init_test_session(conn, current_user: "author1")}
    end

    test "GET /submission/new renders the Make a Submission page", %{conn: conn} do
      conn = get(conn, "/submission/new")
      html = html_response(conn, 200)

      assert html =~ "Make a Submission"
      assert html =~ "Before you begin"
      assert html =~ "Submission Checklist"
      assert html =~ "Privacy Consent"
      assert html =~ "submission-start-form"
      assert html =~ "begin-submission-btn"
      assert html =~ "submission-title"
      assert html =~ "checklist-consent"
      assert html =~ "privacy-consent"
    end

    test "GET /submission/new redirects to login when not authenticated" do
      conn = get(build_conn(), "/submission/new")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "login"
    end

    test "POST /submission/create creates a submission with the title and redirects to the wizard",
         %{conn: conn} do
      conn =
        post(conn, "/submission/create", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "submission" => %{
            "title" => "Judul dari Halaman Make a Submission",
            "checklist" => "1",
            "privacy_consent" => "1"
          }
        })

      assert redirected_to(conn) =~ "/submission/wizard/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "telah dibuat"

      [submission | _] = Submission.get_by_author("author1")
      assert submission.title == "Judul dari Halaman Make a Submission"
    end

    test "POST /submission/create re-renders the form when the title is blank", %{conn: conn} do
      conn =
        post(conn, "/submission/create", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "submission" => %{"title" => "  "}
        })

      html = html_response(conn, 200)
      assert html =~ "Make a Submission"
      assert html =~ "Judul wajib diisi"
    end
  end

  describe "make a submission: details (OJS 3.5 wizard)" do
    setup %{conn: conn} do
      {:ok, conn: init_test_session(conn, current_user: "author1")}
    end

    test "GET /submission/:id/details renders the page", %{conn: conn} do
      conn = get(conn, "/submission/14/details")
      html = html_response(conn, 200)

      assert html =~ "Make a Submission: Details"
      assert html =~ "Dashboard"
      assert html =~ "My Submissions"
      assert html =~ "Submission 14"
      assert html =~ "submission-details-form"
      assert html =~ "abstract-editor"
      assert html =~ "abstract-toolbar"
      assert html =~ "ojs-progress-steps"
      assert html =~ "btn-continue"
      assert html =~ "btn-save-later"
      assert html =~ "Last saved 16 minutes ago"
      assert html =~ "Upload Files"
      assert html =~ "For the Editors"
    end

    test "GET /submission/:id/details redirects to login when not authenticated" do
      conn = get(build_conn(), "/submission/14/details")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "login"
    end

    test "GET /submission/:id/details redirects to my submissions when not found", %{conn: conn} do
      conn = get(conn, "/submission/9999/details")

      assert redirected_to(conn) == "/dashboard/mySubmissions"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "tidak ditemukan"
    end

    test "POST /submission/:id/details saves and continues to upload files", %{conn: conn} do
      submission = Submission.create("author1")

      conn =
        post(conn, "/submission/#{submission.id}/details", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "action" => "continue",
          "submission" => %{
            "title" => "Judul Detail Baru",
            "abstract" => "Abstrak dari halaman details.",
            "keywords" => "elixir, phoenix",
            "references" => "1. Author. (2026). Title."
          }
        })

      assert redirected_to(conn) == "/submission/wizard/#{submission.id}?tab=files"

      updated = Submission.get(submission.id)
      assert updated.title == "Judul Detail Baru"
      assert updated.abstract == "Abstrak dari halaman details."
      assert updated.keywords == "elixir, phoenix"
      assert updated.references == "1. Author. (2026). Title."
    end

    test "POST /submission/:id/details saves for later and returns to my submissions", %{
      conn: conn
    } do
      submission = Submission.create("author1")

      conn =
        post(conn, "/submission/#{submission.id}/details", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "action" => "save",
          "submission" => %{"title" => "Judul Simpan Nanti", "abstract" => "Abstrak singkat."}
        })

      assert redirected_to(conn) ==
               "/dashboard/mySubmissions?currentViewId=incomplete-submissions"

      assert Submission.get(submission.id).title == "Judul Simpan Nanti"
    end

    test "POST /submission/:id/details re-renders with errors when required fields are blank",
         %{conn: conn} do
      submission = Submission.create("author1")

      conn =
        post(conn, "/submission/#{submission.id}/details", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "action" => "continue",
          "submission" => %{"title" => "  ", "abstract" => ""}
        })

      html = html_response(conn, 200)
      assert html =~ "A title is required."
      assert html =~ "An abstract is required."
      assert html =~ "Make a Submission: Details"
    end
  end
end
