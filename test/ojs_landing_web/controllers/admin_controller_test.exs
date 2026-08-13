defmodule OjsLandingWeb.AdminControllerTest do
  use OjsLandingWeb.ConnCase

  @panels [
    {"setup", "Site Setup"},
    {"siteContact", "Site Contact"},
    {"logoFooter", "Logo & Footer"},
    {"banners", "Banners"},
    {"sidebar", "Sidebar"},
    {"navigation", "Navigation Menus"},
    {"plugins", "Plugins"},
    {"pluginGallery", "Plugin Gallery"},
    {"theme", "Theme"},
    {"language", "Language"},
    {"registration", "Registration & Password"},
    {"redirect", "Redirect"},
    {"advanced", "Advanced"},
    {"bulkEmail", "Bulk Email"}
  ]

  describe "authentication & role access for /admin/settings" do
    test "redirects to login when not authenticated" do
      conn = get(build_conn(), "/admin/settings")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Akses ditolak"
    end

    test "redirects non-admin users away from site settings" do
      conn =
        build_conn()
        |> login_as("author1")
        |> get("/admin/settings")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Hanya admin"
    end

    test "redirects editors away from site settings" do
      conn =
        build_conn()
        |> login_as("editor")
        |> get("/admin/settings")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Hanya admin"
    end

    test "allows admin users to open site settings" do
      conn = admin_get("/admin/settings")

      assert html_response(conn, 200) =~ "Site Settings"
    end
  end

  describe "GET /admin/settings uses the OJS admin layout" do
    test "renders inside the admin layout shell" do
      conn = admin_get("/admin/settings")
      html = html_response(conn, 200)

      assert html =~ ~s(class="admin-body")
      assert html =~ "Open Journal Systems"
      assert html =~ ~s(class="admin-header")
    end
  end

  describe "GET /admin/settings main tab navigation" do
    test "renders the horizontal main tab bar with all panel links" do
      conn = admin_get("/admin/settings")
      html = html_response(conn, 200)

      assert html =~ ~s(class="site-settings-tabs")
      assert html =~ ~s(class="site-settings-tab is-active")

      for {_anchor, label} <- @panels do
        assert html =~ String.replace(label, "&", "&amp;")
      end
    end

    test "only renders the first panel as the active tab" do
      conn = admin_get("/admin/settings")
      html = html_response(conn, 200)

      assert html =~ ~s(class="site-settings-tab is-active" data-site-settings-tab="setup")
      assert html =~ ~s(class="site-settings-tab " data-site-settings-tab="plugins")
    end
  end

  describe "GET /admin/settings panels" do
    test "renders all 14 OJS site settings panels" do
      conn = admin_get("/admin/settings")
      html = html_response(conn, 200)

      for {anchor, _label} <- @panels do
        assert html =~ ~s(id="#{anchor}")
      end
    end

    test "renders the site setup fields" do
      conn = admin_get("/admin/settings")
      html = html_response(conn, 200)

      assert html =~ "site[siteName]"
      assert html =~ "site[siteDescription]"
      assert html =~ "site[siteContactEmail]"
      assert html =~ "site[minPasswordLength]"
    end

    test "renders the plugins panel and plugin gallery" do
      conn = admin_get("/admin/settings")
      html = html_response(conn, 200)

      assert html =~ "Installed Plugins"
      assert html =~ "defaultTheme"
      assert html =~ ~s(class="plugin-gallery-grid")
      assert html =~ "Quick Submit"
    end

    test "renders the bulk email journals table" do
      conn = admin_get("/admin/settings")
      html = html_response(conn, 200)

      assert html =~ "Enable Bulk Email"
      assert html =~ "site[bulkEmail][]"
    end
  end

  describe "GET /admin/systemInfo" do
    test "renders the system information page in the admin layout" do
      conn = admin_get("/admin/systemInfo")
      html = html_response(conn, 200)

      assert html =~ ~s(class="admin-body")
      assert html =~ "System Information"
      assert html =~ ~s(Administration)
      assert html =~ "Server Information"
    end

    test "renders version information rows" do
      conn = admin_get("/admin/systemInfo")
      html = html_response(conn, 200)

      assert html =~ "Version Information"
      assert html =~ "OJS Landing Version"
      assert html =~ "Elixir Version"
      assert html =~ "Erlang/OTP Version"
      assert html =~ "Operating System"
      assert html =~ System.version()
    end

    test "renders configuration and extended information" do
      conn = admin_get("/admin/systemInfo")
      html = html_response(conn, 200)

      assert html =~ "Configuration Settings"
      assert html =~ "System Architecture"
      assert html =~ "Logical Processors"
      assert html =~ "Uptime"
      assert html =~ "Extended Information"
      assert html =~ "Hosted Journals"
      assert html =~ "Installed Plugins"
    end

    test "renders maintenance task links" do
      conn = admin_get("/admin/systemInfo")
      html = html_response(conn, 200)

      assert html =~ "Maintenance Tasks"
      assert html =~ ~s(href="/admin/clearDataCache")
      assert html =~ ~s(href="/admin/clearTemplateCache")
      assert html =~ ~s(href="/admin/expireSessions")
      assert html =~ ~s(href="/admin/phpinfo")
    end
  end

  describe "GET /admin/jobs" do
    test "redirects to login when not authenticated" do
      conn = get(build_conn(), "/admin/jobs")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Akses ditolak"
    end

    test "renders the queued jobs page in the admin layout" do
      conn = admin_get("/admin/jobs")
      html = html_response(conn, 200)

      assert html =~ ~s(class="admin-body")
      assert html =~ "View queued jobs"
      assert html =~ ~s(href="/admin/failedJobs")
    end

    test "renders the queued jobs table columns" do
      conn = admin_get("/admin/jobs")
      html = html_response(conn, 200)

      assert html =~ "jobs-table"
      assert html =~ "CompileSubmissionMetrics"
      assert html =~ "CompileIssueMetrics"
      assert html =~ "Attempts"
      assert html =~ "Created At"
    end
  end

  describe "GET /admin/failedJobs" do
    test "redirects to login when not authenticated" do
      conn = get(build_conn(), "/admin/failedJobs")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Akses ditolak"
    end

    test "renders the failed jobs page in the admin layout" do
      conn = admin_get("/admin/failedJobs")
      html = html_response(conn, 200)

      assert html =~ ~s(class="admin-body")
      assert html =~ "Failed Jobs"
      assert html =~ "Requeue All Failed Jobs"
    end

    test "renders the failed jobs table and actions" do
      conn = admin_get("/admin/failedJobs")
      html = html_response(conn, 200)

      assert html =~ "failed-jobs-table"
      assert html =~ "ProcessUsageStatsLogFile"
      assert html =~ "Connection"
      assert html =~ "Failed At"
      assert html =~ "Try Again"
      assert html =~ "Details"
      assert html =~ ~s(href="/admin/failedJobDetails/101")
    end
  end

  describe "GET /admin/failedJobDetails/:id" do
    test "redirects to login when not authenticated" do
      conn = get(build_conn(), "/admin/failedJobDetails/101")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Akses ditolak"
    end

    test "renders the failed job details page" do
      conn = admin_get("/admin/failedJobDetails/101")
      html = html_response(conn, 200)

      assert html =~ ~s(class="admin-body")
      assert html =~ "Failed Job Details"
      assert html =~ "failed-job-details-table"
      assert html =~ "ProcessUsageStatsLogFile"
      assert html =~ "database"
      assert html =~ ~s(href="/admin/failedJobs")
    end

    test "renders a fallback row for an unknown job id" do
      conn = admin_get("/admin/failedJobDetails/999")
      html = html_response(conn, 200)

      assert html =~ "Unknown Job"
      assert html =~ "No details available for this failed job."
    end
  end

  defp login_as(conn, username) do
    init_test_session(conn, current_user: username)
  end

  defp admin_get(path) do
    build_conn()
    |> login_as("alief")
    |> get(path)
  end
end
