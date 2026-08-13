defmodule OjsLandingWeb.SettingsControllerTest do
  use OjsLandingWeb.ConnCase

  describe "authentication & role access" do
    test "redirects to login when not authenticated" do
      conn = get(build_conn(), "/informatika/management/settings/distribution")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Akses ditolak"
    end

    test "redirects non-admin non-editor users away from settings" do
      conn =
        build_conn()
        |> login_as("author1")
        |> get("/informatika/management/settings/context")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Hanya admin atau editor"
    end

    test "allows admin users to open settings" do
      conn =
        build_conn()
        |> login_as("alief")
        |> get("/informatika/management/settings/distribution")

      assert html_response(conn, 200) =~ "Settings"
    end

    test "allows editor users to open settings" do
      conn =
        build_conn()
        |> login_as("editor")
        |> get("/informatika/management/settings/context")

      assert html_response(conn, 200) =~ "Settings"
    end
  end

  defp login_as(conn, username) do
    init_test_session(conn, current_user: username)
  end

  describe "GET /:journal/management/settings" do
    test "redirects to the Journal settings page" do
      conn = admin_get("/informatika/management/settings")

      assert redirected_to(conn) == "/informatika/management/settings/context"
    end

    test "redirects home when the journal is not found" do
      conn = admin_get("/not-a-journal/management/settings")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not found"
    end
  end

  describe "GET /:journal/management/settings/:section" do
    test "renders the Journal (context) settings page" do
      conn = admin_get("/informatika/management/settings/context")
      html = html_response(conn, 200)

      assert html =~ "Settings"
      assert html =~ "Journal Masthead"
      assert html =~ ~s(id="masthead")
      assert html =~ ~s(id="contact")
      assert html =~ ~s(id="sections")
      assert html =~ ~s(id="categories")
    end

    test "renders the Website settings page" do
      conn = admin_get("/informatika/management/settings/website")
      html = html_response(conn, 200)

      assert html =~ "Website Setup"
      assert html =~ ~s(id="setup")
      assert html =~ ~s(id="plugins")
    end

    test "renders the Workflow settings page" do
      conn = admin_get("/informatika/management/settings/workflow")
      html = html_response(conn, 200)

      assert html =~ "Submission"
      assert html =~ ~s(id="review")
      assert html =~ ~s(id="library")
      assert html =~ ~s(id="emails")
    end

    test "renders the Distribution settings page with all anchors" do
      conn = admin_get("/informatika/management/settings/distribution")
      html = html_response(conn, 200)

      assert html =~ "License"
      assert html =~ ~s(id="dois")
      assert html =~ ~s(id="indexing")
      assert html =~ ~s(id="payments")
      assert html =~ ~s(id="access")
      assert html =~ ~s(id="archive")
    end

    test "renders the Users & Roles (access) settings page" do
      conn = admin_get("/informatika/management/settings/access")
      html = html_response(conn, 200)

      assert html =~ "Users"
      assert html =~ ~s(id="roles")
      assert html =~ ~s(id="orcidSettings")
    end

    test "redirects to context settings for an unknown section" do
      conn = admin_get("/informatika/management/settings/notAThing")

      assert redirected_to(conn) == "/informatika/management/settings/context"
    end

    test "redirects home when the journal is not found" do
      conn = admin_get("/not-a-journal/management/settings/distribution")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not found"
    end
  end

  describe "GET /:journal/manageIssues" do
    test "renders the manage issues page for an editor" do
      conn =
        build_conn()
        |> login_as("editor")
        |> get("/informatika/manageIssues")

      html = html_response(conn, 200)

      assert html =~ "Manage Issues"
      assert html =~ ~s(id="issues")
      assert html =~ ~s(id="issue-row-1")
    end

    test "redirects home when the journal is not found" do
      conn = admin_get("/not-a-journal/manageIssues")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not found"
    end

    test "redirects non-admin non-editor users away from manage issues" do
      conn =
        build_conn()
        |> login_as("author1")
        |> get("/informatika/manageIssues")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Hanya admin atau editor"
    end
  end

  describe "GET /:journal/dois" do
    test "renders the DOI management grid for an editor" do
      conn =
        build_conn()
        |> login_as("editor")
        |> get("/informatika/dois")

      html = html_response(conn, 200)

      assert html =~ "DOIs"
      assert html =~ ~s(id="dois")
      assert html =~ "10.1234/informatika.v1i1.1"
      assert html =~ "Sistem Rekomendasi Berbasis Collaborative Filtering untuk E-Learning"
    end

    test "redirects home when the journal is not found" do
      conn = admin_get("/not-a-journal/dois")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not found"
    end

    test "redirects non-admin non-editor users away from the DOI page" do
      conn =
        build_conn()
        |> login_as("author1")
        |> get("/informatika/dois")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Hanya admin atau editor"
    end
  end

  defp admin_get(path) do
    build_conn()
    |> login_as("alief")
    |> get(path)
  end
end
