defmodule OjsLandingWeb.SettingsHTML do
  use OjsLandingWeb, :html

  embed_templates "settings_html/*"

  # =========================================================
  # Settings layout (OJS PKP grouped settings UI)
  # =========================================================

  defp subtabs do
    %{
      "context" => [
        {"masthead", "Masthead"},
        {"contact", "Contact"},
        {"sections", "Sections"},
        {"categories", "Categories"}
      ],
      "website" => [
        {"setup", "Setup"},
        {"plugins", "Plugins"}
      ],
      "workflow" => [
        {"submission", "Submission"},
        {"review", "Review"},
        {"library", "Library"},
        {"emails", "Emails"}
      ],
      "distribution" => [
        {"license", "License"},
        {"dois", "DOI"},
        {"indexing", "Indexing"},
        {"payments", "Payments"},
        {"access", "Access"},
        {"archive", "Archive"}
      ],
      "access" => [
        {"users", "Users"},
        {"roles", "Roles"},
        {"access", "Access"},
        {"orcidSettings", "ORCID"}
      ],
      "issues" => [
        {"issues", "Issues"}
      ]
    }
  end

  attr :section, :string, required: true
  attr :journal_path, :string, required: true
  attr :journal_title, :string, required: true
  slot :inner_block, required: true

  def settings_layout(assigns) do
    ~H"""
    <div class="settings-page">
      <header class="settings-head">
        <div class="settings-breadcrumb">
          <a href="/dashboard">Dashboard</a> <span class="settings-breadcrumb-sep">/</span>
          <a href={~p"/#{@journal_path}/management/settings/context"}>Settings</a>
          <span class="settings-breadcrumb-sep">/</span>
          <span>{settings_section_title(@section)}</span>
        </div>

        <div class="settings-head-row">
          <h1 class="settings-title">Journal Settings</h1>
        </div>
      </header>

      <div class="settings-body">
        <main class="settings-main">
          <nav class="settings-group-tabs" aria-label="Settings groups">
            <%= for {anchor, sub_label} <- Map.fetch!(subtabs(), @section) do %>
              <a
                href={"##{anchor}"}
                class={["settings-group-tab", current_subtab(@section, anchor)]}
                data-settings-subtab={anchor}
              >{sub_label}</a>
            <% end %>
          </nav>

          <div class="settings-content">
            {render_slot(@inner_block)}
          </div>

          <footer class="settings-save-bar">
            <div class="settings-save-actions">
              <button type="submit" form="ojs-settings-form" class="btn-settings-primary">Save</button>
              <a
                href={~p"/#{@journal_path}/management/settings/#{@section}"}
                class="btn-settings-secondary"
              >
                Cancel
              </a>
            </div>
            <span class="settings-save-note">All changes will be applied immediately.</span>
          </footer>
        </main>
      </div>
    </div>

    <script>
      (function () {
        var panels = document.querySelectorAll('.settings-panel[id]');
        var tabs = document.querySelectorAll('.settings-group-tab[data-settings-subtab]');

        function setActive(id) {
          for (var i = 0; i < tabs.length; i++) {
            var tab = tabs[i];
            var key = tab.getAttribute('data-settings-subtab');
            if (key === id) {
              tab.classList.add('is-active');
            } else {
              tab.classList.remove('is-active');
            }
          }
        }

        function currentPanel() {
          var hash = window.location.hash ? window.location.hash.substring(1) : null;
          if (hash) return hash;
          return panels.length ? panels[0].getAttribute('id') : null;
        }

        setActive(currentPanel());

        window.addEventListener('scroll', function () {
          if (window.location.hash) return;
          var best = null;
          for (var i = 0; i < panels.length; i++) {
            var rect = panels[i].getBoundingClientRect();
            if (rect.top <= 150) best = panels[i].getAttribute('id');
          }
          if (best) setActive(best);
        });

        for (var j = 0; j < tabs.length; j++) {
          (function (tab) {
            tab.addEventListener('click', function () { setActive(tab.getAttribute('data-settings-subtab')); });
          })(tabs[j]);
        }
      })();
    </script>
    """
  end

  defp current_subtab(section, anchor) do
    if default_anchor(section) == anchor, do: "is-current", else: false
  end

  defp default_anchor(section) do
    case Map.fetch(subtabs(), section) do
      {:ok, [{anchor, _} | _]} -> anchor
      _ -> nil
    end
  end

  def settings_section_title("context"), do: "Journal"
  def settings_section_title("website"), do: "Website"
  def settings_section_title("workflow"), do: "Workflow"
  def settings_section_title("distribution"), do: "Distribution"
  def settings_section_title("access"), do: "Users & Roles"
  def settings_section_title("issues"), do: "Issues"
  def settings_section_title(_), do: "Settings"

  # =========================================================
  # Form building blocks (OJS PKP form styling)
  # =========================================================

  attr :label, :string, required: true
  attr :hint, :string, default: nil
  attr :name, :string, required: true
  attr :value, :string, default: nil
  attr :type, :string, default: "text"
  attr :placeholder, :string, default: nil
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :autosize, :boolean, default: false
  attr :prefix, :string, default: nil
  attr :suffix, :string, default: nil
  attr :size, :integer, default: nil

  def input_field(assigns) do
    ~H"""
    <div class={["settings-form-row", @autosize && "settings-form-row--full"]}>
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
        <div class={["settings-input-wrap", @size && "settings-input-wrap--fixed"]}>
          <%= if @prefix do %>
            <span class="settings-monogram-prefix">{@prefix}</span>
          <% end %>

          <input
            id={@name}
            name={@name}
            type={@type}
            value={@value}
            placeholder={@placeholder}
            size={@size}
            class="settings-input"
            required={@required}
            disabled={@disabled}
          />
          <%= if @suffix do %>
            <span class="settings-monogram-suffix">{@suffix}</span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :hint, :string, default: nil
  attr :name, :string, required: true
  attr :value, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :rows, :integer, default: 3
  attr :required, :boolean, default: false

  def textarea_field(assigns) do
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
          required={@required}
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

  def select_field(assigns) do
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

  def checkbox_field(assigns) do
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

  def radio_field(assigns) do
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

  attr :label, :string, required: true
  attr :hint, :string, default: nil
  attr :name, :string, required: true
  attr :value, :string, default: nil
  attr :prefix, :string, default: nil
  attr :suffix, :string, default: nil
  attr :size, :integer, default: 8

  def monogram_field(assigns) do
    ~H"""
    <div class="settings-form-row">
      <div class="settings-form-label-col">
        <label class="settings-form-label" for={@name}>{@label}</label>
        <%= if @hint do %>
          <span class="settings-form-hint">{@hint}</span>
        <% end %>
      </div>

      <div class="settings-form-control-col settings-monogram">
        <%= if @prefix do %>
          <span class="settings-monogram-prefix">{@prefix}</span>
        <% end %>

        <input
          id={@name}
          name={@name}
          type="text"
          value={@value}
          class="settings-input"
          size={@size}
        />
        <%= if @suffix do %>
          <span class="settings-monogram-suffix">{@suffix}</span>
        <% end %>
      </div>
    </div>
    """
  end

  # =========================================================
  # OJS-style panel / table helpers
  # =========================================================

  attr :title, :string, required: true
  attr :anchor, :string, required: true
  attr :description, :string, default: nil
  slot :inner_block, required: true

  def settings_panel(assigns) do
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

  attr :title, :string, required: true
  attr :columns, :list, required: true
  attr :rows, :list, default: []
  attr :empty_text, :string, default: "No items available."
  slot :inner_block, required: true

  def settings_table(assigns) do
    ~H"""
    <div class="settings-list">
      <div class="settings-list-head">
        <h3>{@title}</h3>
      </div>

      <div class="settings-table-wrap">
        <table class="settings-table">
          <thead>
            <tr>
              <th :for={col <- @columns}>{col}</th>

              <th class="settings-table-actions-col"></th>
            </tr>
          </thead>

          <tbody>
            <%= if Enum.empty?(@rows) do %>
              <tr>
                <td colspan={length(@columns) + 1} class="settings-table-empty">{@empty_text}</td>
              </tr>
            <% else %>
              {render_slot(@inner_block)}
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  def settings_list_create_button(assigns) do
    ~H"""
    <button type="button" class="btn-settings-link">+ Add</button>
    """
  end

  # =========================================================
  # Issue helpers (Manage Issues)
  # =========================================================

  def issue_volume_label(%{volume: volume, number: number, year: year}) do
    "Vol. #{volume}, No. #{number} (#{year})"
  end

  def issue_volume_label(_), do: "—"

  def issue_status_text(:published), do: "Published"
  def issue_status_text(:scheduled), do: "Scheduled"
  def issue_status_text(_), do: "Unpublished"

  def issue_status_class(:published), do: "is-published"
  def issue_status_class(:scheduled), do: "is-scheduled"
  def issue_status_class(_), do: ""

  def issue_article_count(%{articles: articles}) when is_list(articles), do: length(articles)
  def issue_article_count(_), do: 0

  def issue_groups(issues) do
    %{
      future: Enum.filter(issues, &(&1.status != :published)),
      current: Enum.find(issues, &(&1.status == :published)),
      back: Enum.filter(issues, &(&1.status == :published))
    }
  end

  def issue_published_date(%{published_date: date}) when date in [nil, ""], do: "—"
  def issue_published_date(%{published_date: date}), do: date
  def issue_published_date(_), do: "—"

  def issue_description(%{description: description}) when description in [nil, ""],
    do: "No description provided."

  def issue_description(%{description: description}), do: description
  def issue_description(_), do: "No description provided."

  def issue_cover(%{cover: cover}) when cover in [nil, ""], do: "—"
  def issue_cover(%{cover: cover}), do: cover
  def issue_cover(_), do: "—"

  attr :status, :atom, required: true

  def issue_status_badge(assigns) do
    ~H"""
    <span class={["settings-status", issue_status_class(@status)]}>
      {issue_status_text(@status)}
    </span>
    """
  end

  # =========================================================
  # DOI helpers (Manage DOIs)
  # =========================================================

  def doi_status_text(:needs_doi), do: "Needs DOI"
  def doi_status_text(:assigned), do: "DOI Assigned"
  def doi_status_text(:registered), do: "Registered"
  def doi_status_text(:unregistered), do: "Unregistered"
  def doi_status_text(:submitted), do: "Submitted"
  def doi_status_text(:error), do: "Error"
  def doi_status_text(:stale), do: "Stale"
  def doi_status_text(_), do: "—"

  def doi_status_class(:needs_doi), do: "is-scheduled"
  def doi_status_class(:assigned), do: ""
  def doi_status_class(:registered), do: "is-enabled"
  def doi_status_class(:unregistered), do: ""
  def doi_status_class(:submitted), do: ""
  def doi_status_class(:error), do: "is-error"
  def doi_status_class(:stale), do: "is-scheduled"
  def doi_status_class(_), do: ""

  attr :status, :atom, required: true

  def doi_status_badge(assigns) do
    ~H"""
    <span class={["settings-status", doi_status_class(@status)]}>
      {doi_status_text(@status)}
    </span>
    """
  end

  # =========================================================
  # Sample data helpers (presentational)
  # =========================================================

  def journal_users do
    [
      %{name: "Dr. Ahmad Santoso", username: "ahmad", email: "ahmad@example.org", role: "Editor"},
      %{name: "Dr. Siti Nurhaliza", username: "siti", email: "siti@example.org", role: "Author"},
      %{
        name: "Prof. Bambang Wijaya",
        username: "bambang",
        email: "bambang@example.org",
        role: "Reviewer"
      },
      %{name: "Rudi Hartono", username: "rudi", email: "rudi@example.org", role: "Author"}
    ]
  end

  def journal_roles do
    [
      %{name: "Editor", system_id: "Editor (No department)", users: 1},
      %{name: "Author", system_id: "Author (No department)", users: 2},
      %{name: "Reviewer", system_id: "Reviewer (No department)", users: 1},
      %{name: "Subscription Manager", system_id: "Subscription Manager (No department)", users: 0}
    ]
  end

  def journal_initials(title) do
    title
    |> String.split()
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end

  def sections(_journal) do
    [
      %{
        id: 1,
        name: "Articles",
        abbreviation: "ART",
        policy: "This section publishes original research, reviews, and case studies."
      }
    ]
  end

  def categories(_journal) do
    [
      %{
        id: 1,
        name: "General Science",
        description: "Cross-disciplinary contributions.",
        parent: "—"
      }
    ]
  end

  def journals_list do
    Enum.map(OjsLanding.Journal.all(), &{String.downcase(&1.path || &1.title), &1.title})
  end

  def license_options do
    [
      "—\u00a0Avoid\u00a0copyright\u00a0transfer\u00a0—",
      "CC BY",
      "CC BY-NC",
      "CC BY-ND",
      "CC BY-SA"
    ]
  end

  def indexing_plugins_selected(_section) do
    ["googlescholar", "doaj", "crossref", "openAIRE", "orcid"]
  end

  def review_forms do
    [
      %{
        name: "Standard Peer Review",
        description: "Generic review form with recommendation and comments."
      },
      %{
        name: "Statistical Review",
        description: "Review form focused on statistical methodology."
      }
    ]
  end

  def library_files do
    [
      %{
        name: "Author Guidelines.pdf",
        type: "Guidelines",
        size: "240 KB"
      },
      %{
        name: "Copyright Transfer Agreement.docx",
        type: "Forms",
        size: "82 KB"
      },
      %{
        name: "Reviewer Handbook.pdf",
        type: "Protocol",
        size: "1.2 MB"
      }
    ]
  end

  def email_templates do
    [
      %{name: "Submission Acknowledgment", subject: "Submission received"},
      %{name: "Editorial Assignment", subject: "You have been assigned to this submission"},
      %{name: "Review Request", subject: "Review request"},
      %{name: "Review Completed", subject: "Thank you for your review"},
      %{name: "Article Accepted", subject: "Your submission has been accepted"}
    ]
  end

  def installable_plugins do
    [
      %{
        name: "defaultTheme",
        version: "2.0.0",
        description: "Default Theme plugin for OJS.",
        enabled: true
      },
      %{
        name: "googleScholar",
        version: "1.0.0",
        description: "Adds Google Scholar index tags to article pages.",
        enabled: true
      },
      %{
        name: "doaj",
        version: "1.1.0",
        description: "Supports deposit of journal metadata to DOAJ.",
        enabled: true
      },
      %{
        name: "crossref",
        version: "1.3.2",
        description: "Registers DOIs and article metadata with Crossref.",
        enabled: true
      },
      %{
        name: "orcidProfile",
        version: "2.0.0",
        description: "Allows authors to link their ORCID iD to their profile.",
        enabled: false
      },
      %{
        name: "staticPages",
        version: "1.0.0",
        description: "Create static pages for the front-end.",
        enabled: false
      }
    ]
  end
end
