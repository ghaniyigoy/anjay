defmodule OjsLandingWeb.AdminHTML do
  use OjsLandingWeb, :html
  embed_templates "admin_html/*"

  def journal_settings_path do
    [journal | _] = OjsLanding.Journal.all()
    "/#{journal.path}/management/settings/context"
  end

  def journal_manage_issues_path do
    [journal | _] = OjsLanding.Journal.all()
    "/#{journal.path}/manageIssues"
  end

  def journal_dois_path do
    [journal | _] = OjsLanding.Journal.all()
    "/#{journal.path}/dois"
  end

  # =========================================================
  # Site Settings (OJS 3.5 admin)
  # =========================================================

  @doc """
  The ordered list of panels shown on the Site Settings page.

  Each entry is `{anchor, label}` where `anchor` matches the panel `id`
  rendered by `settings.html.heex`.
  """
  def site_settings_panels do
    [
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
  end

  @doc """
  Layout wrapper for the Site Settings page: breadcrumb header, a horizontal
  main tab bar with one active panel at a time, and a save bar.
  """
  attr :active, :string, default: nil
  slot :inner_block, required: true

  def site_settings_layout(assigns) do
    ~H"""
    <div class="site-settings-page">
      <header class="settings-head site-settings-head">
        <div class="settings-breadcrumb">
          <a href="/admin">Administration</a> <span class="settings-breadcrumb-sep">/</span>
          <span>Site Settings</span>
        </div>

        <div class="settings-head-row">
          <h1 class="settings-title">Site Settings</h1>
        </div>
      </header>

      <div class="site-settings-card">
        <nav class="site-settings-tabs" aria-label="Site settings panels">
          <%= for {anchor, label} <- site_settings_panels() do %>
            <a
              href={"##{anchor}"}
              class={["site-settings-tab", @active == anchor && "is-active"]}
              data-site-settings-tab={anchor}
            >{label}</a>
          <% end %>
        </nav>

        <div class="site-settings-content">
          {render_slot(@inner_block)}
        </div>

        <footer class="settings-save-bar">
          <div class="settings-save-actions">
            <button type="submit" form="site-settings-form" class="btn-settings-primary">Save</button>
            <a href="/admin/settings" class="btn-settings-secondary">Cancel</a>
          </div>
          <span class="settings-save-note">All changes will be applied immediately.</span>
        </footer>
      </div>
    </div>

    <script>
      (function () {
        var tabs = document.querySelectorAll('.site-settings-tab[data-site-settings-tab]');
        var panels = document.querySelectorAll('.site-settings-content .settings-panel');

        function showTab(id) {
          for (var i = 0; i < tabs.length; i++) {
            var tab = tabs[i];
            if (tab.getAttribute('data-site-settings-tab') === id) {
              tab.classList.add('is-active');
            } else {
              tab.classList.remove('is-active');
            }
          }
          for (var j = 0; j < panels.length; j++) {
            var panel = panels[j];
            if (panel.getAttribute('id') === id) {
              panel.classList.add('is-shown');
            } else {
              panel.classList.remove('is-shown');
            }
          }
        }

        function currentTab() {
          var hash = window.location.hash ? window.location.hash.substring(1) : null;
          if (hash && document.querySelector('.site-settings-content .settings-panel#' + hash)) {
            return hash;
          }
          return panels.length ? panels[0].getAttribute('id') : null;
        }

        showTab(currentTab());

        window.addEventListener('hashchange', function () {
          showTab(currentTab());
        });

        for (var k = 0; k < tabs.length; k++) {
          (function (tab) {
            tab.addEventListener('click', function () {
              showTab(tab.getAttribute('data-site-settings-tab'));
            });
          })(tabs[k]);
        }
      })();
    </script>
    """
  end

  @doc """
  OJS style panel block used on the Site Settings page.
  """
  attr :anchor, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :inner_block, required: true

  def site_settings_panel(assigns) do
    ~H"""
    <section id={@anchor} class="settings-panel">
      <div class="settings-panel-head">
        <h2 class="settings-panel-title">{@title}</h2>

        <%= if @description do %>
          <p class="settings-panel-description">{@description}</p>
        <% end %>
      </div>

      <div class="settings-panel-body">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  # ---------------------------------------------------------
  # Site Settings form field components
  # ---------------------------------------------------------

  attr :label, :string, required: true
  attr :hint, :string, default: nil
  attr :name, :string, required: true
  attr :value, :string, default: nil
  attr :type, :string, default: "text"
  attr :placeholder, :string, default: nil
  attr :required, :boolean, default: false
  attr :size, :integer, default: nil

  def site_input_field(assigns) do
    ~H"""
    <div class="settings-form-row">
      <div class="settings-form-label-col">
        <label class="settings-form-label" for={@name}>
          {@label}
          <%= if @required do %>
            <span class="settings-required">*</span>
          <% end %>
        </label>

        <%= if @hint do %>
          <span class="settings-form-hint">{@hint}</span>
        <% end %>
      </div>

      <div class="settings-form-control-col">
        <input
          id={@name}
          name={@name}
          type={@type}
          value={@value}
          placeholder={@placeholder}
          size={@size}
          class="settings-input"
          required={@required}
        />
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :hint, :string, default: nil
  attr :name, :string, required: true
  attr :value, :string, default: nil
  attr :rows, :integer, default: 3
  attr :placeholder, :string, default: nil

  def site_textarea_field(assigns) do
    ~H"""
    <div class="settings-form-row">
      <div class="settings-form-label-col">
        <label class="settings-form-label" for={@name}>{@label}</label>
        <%= if @hint do %>
          <span class="settings-form-hint">{@hint}</span>
        <% end %>
      </div>

      <div class="settings-form-control-col">
        <textarea
          id={@name}
          name={@name}
          rows={@rows}
          placeholder={@placeholder}
          class="settings-input settings-textarea"
        >{@value}</textarea>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :hint, :string, default: nil
  attr :name, :string, required: true
  attr :value, :string, default: nil
  attr :options, :list, default: []
  attr :dropdown, :boolean, default: false

  def site_select_field(assigns) do
    ~H"""
    <div class="settings-form-row">
      <div class="settings-form-label-col">
        <label class="settings-form-label" for={@name}>{@label}</label>
        <%= if @hint do %>
          <span class="settings-form-hint">{@hint}</span>
        <% end %>
      </div>

      <div class="settings-form-control-col">
        <select
          id={@name}
          name={@name}
          class={["settings-input", @dropdown && "settings-input--dropdown"]}
        >
          <option value="" disabled selected={@value in [nil, ""]}>Please select...</option>

          <%= for {option_value, option_label} <- @options do %>
            <option value={option_value} selected={option_value == @value}>{option_label}</option>
          <% end %>
        </select>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :hint, :string, default: nil
  attr :name, :string, required: true
  attr :value, :list, default: []
  attr :options, :list, default: []

  def site_checkbox_field(assigns) do
    ~H"""
    <div class="settings-form-row settings-form-row--check">
      <div class="settings-form-label-col settings-form-label-col--check">
        <span class="settings-form-label">{@label}</span>
        <%= if @hint do %>
          <span class="settings-form-hint">{@hint}</span>
        <% end %>
      </div>

      <div class="settings-form-control-col">
        <%= for {option_value, option_label} <- @options do %>
          <label class="settings-checkbox">
            <input
              type="checkbox"
              name={@name}
              value={option_value}
              checked={option_value in @value}
            /> <span>{option_label}</span>
          </label>
        <% end %>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :hint, :string, default: nil
  attr :name, :string, required: true
  attr :value, :string, default: nil
  attr :options, :list, default: []
  attr :inline, :boolean, default: false

  def site_radio_field(assigns) do
    ~H"""
    <div class="settings-form-row">
      <div class="settings-form-label-col">
        <span class="settings-form-label">{@label}</span>
        <%= if @hint do %>
          <span class="settings-form-hint">{@hint}</span>
        <% end %>
      </div>

      <div class={["settings-form-control-col", @inline && "settings-form-control-col--inline"]}>
        <%= for {option_value, option_label} <- @options do %>
          <label class="settings-radio">
            <input
              type="radio"
              name={@name}
              value={option_value}
              checked={option_value == @value}
            /> <span>{option_label}</span>
          </label>
        <% end %>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------
  # Site Settings data helpers
  # ---------------------------------------------------------

  def site_themes do
    [
      {"defaultTheme", "Default Theme"},
      {"classicTheme", "Classic Theme"},
      {"immersionTheme", "Immersion"},
      {"healthSciencesTheme", "Health Sciences"}
    ]
  end

  def site_sidebar_blocks do
    [
      {"readerTools", "Reader Tools", true},
      {"languageToggle", "Language Toggle", true},
      {"webFeed", "Web Feed", true},
      {"navigationMenu", "Navigation Menu", true},
      {"customBlock", "Custom Block", false},
      {"information", "Information", true}
    ]
  end

  def site_block_options do
    Enum.map(site_sidebar_blocks(), fn {value, label, _enabled} -> {value, label} end)
  end

  def site_selected_blocks do
    for {value, _label, enabled} <- site_sidebar_blocks(), enabled, do: value
  end

  def site_languages do
    [
      {"en_US", "English (United States)"},
      {"id_ID", "Bahasa Indonesia"},
      {"ar_IQ", "العربية"},
      {"es_ES", "Español (España)"},
      {"pt_BR", "Português (Brasil)"}
    ]
  end

  def site_installed_plugins do
    [
      %{
        name: "defaultTheme",
        version: "2.0.0",
        description: "Default theme for OJS.",
        category: "Theme",
        enabled: true,
        required: false
      },
      %{
        name: "googleScholar",
        version: "1.0.0",
        description: "Adds Google Scholar index tags to article pages.",
        category: "Generic",
        enabled: true,
        required: false
      },
      %{
        name: "doaj",
        version: "1.1.0",
        description: "Supports deposit of journal metadata to DOAJ.",
        category: "Generic",
        enabled: true,
        required: false
      },
      %{
        name: "crossref",
        version: "1.3.2",
        description: "Registers DOIs and article metadata with Crossref.",
        category: "Generic",
        enabled: true,
        required: false
      },
      %{
        name: "orcidProfile",
        version: "2.0.0",
        description: "Allows authors to link their ORCID iD to their profile.",
        category: "Generic",
        enabled: false,
        required: false
      },
      %{
        name: "staticPages",
        version: "1.0.0",
        description: "Create static pages for the front-end.",
        category: "Generic",
        enabled: false,
        required: false
      },
      %{
        name: "customBlockManager",
        version: "1.0.0",
        description: "Create and manage custom sidebar blocks.",
        category: "Generic",
        enabled: true,
        required: false
      }
    ]
  end

  def site_plugin_gallery do
    [
      %{
        name: "quickSubmit",
        display_name: "Quick Submit",
        category: "Generic",
        version: "1.0.0",
        description: "Provides a simplified method for adding articles directly to the system.",
        status: "Not installed"
      },
      %{
        name: "noContexts",
        display_name: "No Contexts",
        category: "Generic",
        version: "1.0.0",
        description: "Hides the journal selector from the site front-end.",
        status: "Not installed"
      },
      %{
        name: "themeMonograph",
        display_name: "Monograph Theme",
        category: "Theme",
        version: "1.0.0",
        description: "A clean reading theme inspired by digital books.",
        status: "Not installed"
      },
      %{
        name: "ojsArticleScrape",
        display_name: "Article Scrape",
        category: "Generic",
        version: "1.0.0",
        description: "Exports article metadata for external indexing services.",
        status: "Not installed"
      },
      %{
        name: "statisticsReport",
        display_name: "Statistics Report",
        category: "Generic",
        version: "1.0.0",
        description: "Builds custom statistics reports for journals.",
        status: "Not installed"
      }
    ]
  end

  def site_journal_options do
    Enum.map(OjsLanding.Journal.all(), &{&1.path, &1.title})
  end

  # =========================================================
  # System Information (OJS 3.5 admin)
  # =========================================================

  @doc """
  Version information rows shown on the System Information page.
  """
  def system_info_version do
    [
      {"OJS Landing Version", app_version()},
      {"Elixir Version", System.version()},
      {"Erlang/OTP Version", System.otp_release()},
      {"Operating System", os_name()},
      {"Server Software", "Bandit #{bandit_version()}"},
      {"Environment", Atom.to_string(Mix.env())}
    ]
  end

  @doc """
  Runtime configuration rows shown on the System Information page.
  """
  def system_info_configuration do
    memory = :erlang.memory()

    [
      {"System Architecture", to_string(:erlang.system_info(:system_architecture))},
      {"Schedulers",
       "#{:erlang.system_info(:schedulers_online)} online / #{:erlang.system_info(:schedulers)} total"},
      {"Logical Processors", to_string(:erlang.system_info(:logical_processors))},
      {"Total Memory", format_bytes(memory[:total])},
      {"Memory Used", format_bytes(memory[:total] - memory[:system])},
      {"Atom Count", "#{:erlang.system_info(:atom_count)} / #{:erlang.system_info(:atom_limit)}"},
      {"Process Count", to_string(:erlang.system_info(:process_count))},
      {"Erlang Node", Atom.to_string(Node.self())},
      {"Uptime", format_uptime()}
    ]
  end

  @doc """
  Extended information rows shown on the System Information page.
  """
  def system_info_extended do
    [
      {"Loaded Applications", to_string(length(Application.loaded_applications()))},
      {"Hosted Journals", to_string(length(OjsLanding.Journal.all()))},
      {"Registered Users", to_string(length(OjsLanding.User.all()))},
      {"Installed Plugins", to_string(length(site_installed_plugins()))}
    ]
  end

  defp app_version do
    Application.spec(:ojs_landing, :vsn) || "dev"
  end

  defp bandit_version do
    Application.spec(:bandit, :vsn) || "n/a"
  end

  defp os_name do
    case :os.type() do
      {:unix, :linux} -> "Linux"
      {:unix, :darwin} -> "macOS"
      {:unix, :freebsd} -> "FreeBSD"
      {:unix, :openbsd} -> "OpenBSD"
      {:unix, :sunos} -> "Solaris"
      {:win32, :nt} -> "Windows"
      {:win32, name} -> "Windows (#{name})"
      other -> inspect(other)
    end
  end

  defp format_uptime do
    total_seconds = elem(:erlang.statistics(:wall_clock), 0)

    days = div(total_seconds, 86_400)
    hours = div(rem(total_seconds, 86_400), 3_600)
    minutes = div(rem(total_seconds, 3_600), 60)
    seconds = rem(total_seconds, 60)

    Enum.join(
      Enum.reject(
        [
          days > 0 && "#{days}d",
          hours > 0 && "#{hours}h",
          minutes > 0 && "#{minutes}m",
          "#{seconds}s"
        ],
        &(&1 == false)
      ),
      " "
    )
  end

  defp format_bytes(bytes) when bytes >= 1_073_741_824 do
    "#{:erlang.float_to_binary(bytes / 1_073_741_824, decimals: 2)} GB"
  end

  defp format_bytes(bytes) when bytes >= 1_048_576 do
    "#{:erlang.float_to_binary(bytes / 1_048_576, decimals: 1)} MB"
  end

  defp format_bytes(bytes) when bytes >= 1024 do
    "#{:erlang.float_to_binary(bytes / 1024, decimals: 1)} KB"
  end

  defp format_bytes(bytes), do: "#{bytes} B"

  @doc """
  Label/value table used on the System Information page.
  """
  attr :title, :string, required: true
  attr :rows, :list, required: true

  def system_info_table(assigns) do
    ~H"""
    <div class="settings-subblock">
      <h4 class="settings-subblock-title">{@title}</h4>

      <div class="settings-table-wrap">
        <table class="settings-table system-info-table">
          <tbody>
            <%= for {label, value} <- @rows do %>
              <tr>
                <th class="system-info-label">{label}</th>

                <td class="system-info-value">{value}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # =========================================================
  # Jobs & Failed Jobs (OJS 3.5 admin)
  # =========================================================

  @doc """
  Sample list of queued jobs waiting to be executed.
  """
  def queued_jobs do
    [
      %{
        id: 1,
        display_name: "PKP\\jobs\\statistics\\CompileSubmissionMetrics",
        queue: "queue",
        attempts: 0,
        created_at: "2026-08-13 07:12:05 UTC +0000"
      },
      %{
        id: 2,
        display_name: "PKP\\jobs\\statistics\\CompileIssueMetrics",
        queue: "queue",
        attempts: 0,
        created_at: "2026-08-13 07:12:06 UTC +0000"
      },
      %{
        id: 3,
        display_name: "PKP\\jobs\\statistics\\ProcessUsageStatsLogFile",
        queue: "queue",
        attempts: 1,
        created_at: "2026-08-13 07:11:58 UTC +0000"
      },
      %{
        id: 4,
        display_name: "APP\\jobs\\submissions\\UpdateSubmissionSearchJob",
        queue: "queue",
        attempts: 0,
        created_at: "2026-08-13 06:48:21 UTC +0000"
      },
      %{
        id: 5,
        display_name: "PKP\\jobs\\doi\\DepositSubmission",
        queue: "queue",
        attempts: 2,
        created_at: "2026-08-13 06:30:10 UTC +0000"
      }
    ]
  end

  @doc """
  Sample list of failed jobs.
  """
  def failed_jobs do
    [
      %{
        id: 101,
        display_name: "PKP\\jobs\\statistics\\ProcessUsageStatsLogFile",
        queue: "queue",
        connection: "database",
        failed_at: "2026-08-13 07:20:44 UTC +0000",
        exception:
          "Illuminate\\Database\\QueryException: SQLSTATE[HY000]: General error: 5 database is locked " <>
            "(SQL: update `jobs` set `reserved_at` = ? where `id` = ?) in " <>
            "/var/www/ojs/lib/pkp/vendor/laravel/framework/src/Illuminate/Database/Connection.php"
      },
      %{
        id: 102,
        display_name: "PKP\\jobs\\doi\\DepositSubmission",
        queue: "queue",
        connection: "database",
        failed_at: "2026-08-13 06:41:12 UTC +0000",
        exception:
          "GuzzleHttp\\Exception\\ConnectException: cURL error 28: Connection timed out " <>
            "after 10001 milliseconds in " <>
            "/var/www/ojs/lib/pkp/vendor/guzzlehttp/guzzle/src/Handler/CurlFactory.php"
      },
      %{
        id: 103,
        display_name: "PKP\\jobs\\email\\ReviewReminder",
        queue: "queue",
        connection: "database",
        failed_at: "2026-08-12 22:15:33 UTC +0000",
        exception:
          "Swift_TransportException: Connection could not be established with host smtp.example.com " <>
            ":stream_socket_client(): unable to connect to tcp://smtp.example.com:587"
      }
    ]
  end

  @doc """
  Look up a single failed job by id (used on the Failed Job Details page).
  """
  def failed_job(id) when is_binary(id) do
    failed_job(String.to_integer(id))
  end

  def failed_job(id) do
    Enum.find(failed_jobs(), &(&1.id == id)) ||
      %{
        id: id,
        display_name: "Unknown Job",
        queue: "-",
        connection: "-",
        failed_at: "-",
        exception: "No details available for this failed job."
      }
  end

  @doc """
  Build the attribute/value rows shown on the Failed Job Details page.
  """
  def failed_job_details_rows(failed_job) do
    [
      {"ID", failed_job.id},
      {"Job", failed_job.display_name},
      {"Queue", failed_job.queue},
      {"Connection", failed_job.connection},
      {"Failed At", failed_job.failed_at},
      {"Exception", failed_job.exception}
    ]
  end
end
