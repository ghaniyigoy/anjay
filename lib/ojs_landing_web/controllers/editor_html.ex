defmodule OjsLandingWeb.EditorHTML do
  use OjsLandingWeb, :html
  embed_templates "editor_html/*"

  def badge_class(view_id, count) do
    cond do
      view_id == "reviews-overdue" and count > 0 -> "badge-danger"
      count > 0 -> "badge-default"
      true -> "badge-zero"
    end
  end

  def stage_label(:needs_editor), do: "Needs Editor"
  def stage_label(:initial_review), do: "Initial Review"
  def stage_label(:needs_reviews), do: "Needs Reviews"
  def stage_label(:awaiting_reviews), do: "Awaiting Reviews"
  def stage_label(:reviews_submitted), do: "Reviews Submitted"
  def stage_label(:external_review), do: "External Review"
  def stage_label(:copyediting), do: "Copyediting"
  def stage_label(:production), do: "Production"
  def stage_label(:scheduled), do: "Scheduled"
  def stage_label(:published), do: "Published"
  def stage_label(:declined), do: "Declined"
  def stage_label(_), do: "Submission"

  def stage_color(:needs_editor), do: "#9b59b6"
  def stage_color(:initial_review), do: "#3498db"
  def stage_color(:needs_reviews), do: "#f39c12"
  def stage_color(:awaiting_reviews), do: "#3498db"
  def stage_color(:reviews_submitted), do: "#27ae60"
  def stage_color(:external_review), do: "#9b59b6"
  def stage_color(:copyediting), do: "#e67e22"
  def stage_color(:production), do: "#e74c3c"
  def stage_color(_), do: "#95a5a6"

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

  def journal_stats_path do
    [journal | _] = OjsLanding.Journal.all()
    "/#{journal.path}/stats/publications/publications"
  end

  def journal_settings_links do
    base = journal_settings_path() |> String.replace("/context", "")

    [
      {"Journal", "#{base}/context"},
      {"Website", "#{base}/website"},
      {"Workflow", "#{base}/workflow"},
      {"Distribution", "#{base}/distribution"},
      {"Users & Roles", "#{base}/access"}
    ]
  end

  def journal_stats_links do
    base = journal_stats_path() |> String.replace("/publications", "")

    [
      {"Publications", "#{base}/publications/publications"},
      {"Issues", "#{base}/issues/issues"},
      {"Context", "#{base}/context/context"},
      {"Editorial", "#{base}/editorial/editorial"},
      {"Users", "#{base}/users/users"},
      {"COUNTER R5", "#{base}/counterR5/counterR5"},
      {"Reports", "#{base}/reports"}
    ]
  end

  # Workflow stage navigation (under the WORKFLOW sidebar heading)
  def workflow_sections do
    [
      {"Submission", "submission"},
      {"Review", "review"},
      {"Copyediting", "copyediting"},
      {"Production", "production"}
    ]
  end

  # Publication sub-menus (under the PUBLICATION sidebar heading)
  def publication_sections do
    [
      {"Title & Abstract", "title-abstract"},
      {"Contributors", "contributors"},
      {"Metadata", "metadata"},
      {"References", "references"},
      {"JATS XML", "jats-xml"},
      {"Galley", "galley"},
      {"Permissions & Disclosure", "permissions"},
      {"Issue", "issue"}
    ]
  end

  # Absolute path used by the sidebar links to switch between sections of a
  # given submission detail. The base workflow section ("submission") uses the
  # submission URL without an extra segment.
  def submission_section_path(submission_id, "submission") do
    "/dashboard/editorial/submissions/#{submission_id}"
  end

  def submission_section_path(submission_id, section) do
    "/dashboard/editorial/submissions/#{submission_id}/#{section}"
  end

  attr :submission, :map, required: true
  attr :active_section, :string, default: "submission"
  slot :inner_block, required: true

  def submission_workflow_layout(assigns) do
    ~H"""
    <div class="submission-detail-page">
      <%!-- Submission header / top bar --%>
      <div class="submission-header">
        <div class="submission-header-main">
          <div class="submission-header-row">
            <a
              href="/dashboard/editorial?currentViewId=assigned-to-me"
              class="submission-back-btn"
            >
              <span class="submission-back-icon">&#8592;</span> Back
            </a>

            <span class="submission-id">Submission {@submission.id}</span>

            <span class="submission-stage-indicator">
              <span class="submission-stage-dot"></span>
              {@submission.stage_label}
            </span>
          </div>

          <h1 class="submission-title">{@submission.author}</h1>

          <div class="submission-authors">{@submission.title}</div>
        </div>

        <div class="submission-header-actions">
          <a href="#" class="submission-header-btn">Activity Log</a>
          <a href="#" class="submission-header-btn">Library</a>
        </div>
      </div>

      <%!-- Body: sidebar + main content --%>
      <div class="submission-detail-body">
        <%!-- Left sidebar --%>
        <aside class="submission-sidebar">
          <div class={[
            "submission-nav-section",
            is_workflow_section?(@active_section) && "is-open"
          ]}>
            <button
              type="button"
              class="submission-nav-toggle"
              onclick="toggleSubmissionNav(this)"
              aria-expanded={if is_workflow_section?(@active_section), do: "true", else: "false"}
            >
              <span class="submission-nav-toggle-label">Workflow</span>
              <span class="submission-nav-arrow">&#9662;</span>
            </button>

            <ul class="submission-nav-list">
              <%= for {label, sec} <- workflow_sections() do %>
                <li class={if @active_section == sec, do: "active"}>
                  <a href={submission_section_path(@submission.id, sec)}>{label}</a>
                </li>
              <% end %>
            </ul>
          </div>

          <div class={[
            "submission-nav-section",
            is_publication_section?(@active_section) && "is-open"
          ]}>
            <button
              type="button"
              class="submission-nav-toggle"
              onclick="toggleSubmissionNav(this)"
              aria-expanded={if is_publication_section?(@active_section), do: "true", else: "false"}
            >
              <span class="submission-nav-toggle-label">Publication</span>
              <span class="submission-nav-arrow">&#9656;</span>
            </button>

            <ul class="submission-nav-list">
              <%= for {label, sec} <- publication_sections() do %>
                <li class={if @active_section == sec, do: "active"}>
                  <a href={submission_section_path(@submission.id, sec)}>{label}</a>
                </li>
              <% end %>
            </ul>
          </div>
        </aside>

        {render_slot(@inner_block)}
      </div>
    </div>

    <script>
      function toggleSubmissionNav(button) {
        var section = button.parentElement;
        var list = section.querySelector('.submission-nav-list');
        var arrow = section.querySelector('.submission-nav-arrow');
        var isOpen = section.classList.contains('is-open');

        if (isOpen) {
          section.classList.remove('is-open');
          list.style.display = 'none';
          arrow.innerHTML = '&#9656;';
          button.setAttribute('aria-expanded', 'false');
        } else {
          section.classList.add('is-open');
          list.style.display = 'block';
          arrow.innerHTML = '&#9662;';
          button.setAttribute('aria-expanded', 'true');
        }
      }

      function toggleRowMenu(button) {
        var menu = button.parentElement.querySelector('.submission-row-menu');
        if (menu) {
          var open = menu.classList.contains('visible');
          document.querySelectorAll('.submission-row-menu.visible').forEach(function (m) {
            m.classList.remove('visible');
          });
          if (!open) menu.classList.add('visible');
        }
      }

      document.addEventListener('click', function (e) {
        if (!e.target.closest('.submission-row-menu') && !e.target.closest('.submission-ellipsis')) {
          document.querySelectorAll('.submission-row-menu.visible').forEach(function (m) {
            m.classList.remove('visible');
          });
        }
      });
    </script>
    """
  end

  defp is_workflow_section?("submission"), do: true
  defp is_workflow_section?("review"), do: true
  defp is_workflow_section?("copyediting"), do: true
  defp is_workflow_section?("production"), do: true
  defp is_workflow_section?(_), do: false

  defp is_publication_section?(sec) do
    sec in [
      "title-abstract",
      "contributors",
      "metadata",
      "references",
      "jats-xml",
      "galley",
      "permissions",
      "issue"
    ]
  end

  attr :title, :string, required: true
  attr :submission, :map, required: true
  slot :actions
  slot :inner_block

  def workflow_page(assigns) do
    ~H"""
    <div class="submission-main-content">
      <div class="workflow-page">
        <div class="workflow-status-bar">
          <div class="workflow-status-title">
            <h2>{@title}</h2>
            <span class="submission-workflow-label">Workflow</span>
          </div>

          <span class="workflow-language">
            Manuscript Language: {@submission.language}
          </span>

          <div class="workflow-status-actions">
            {render_slot(@actions)}
          </div>
        </div>

        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :files, :list, default: []

  def workflow_files(assigns) do
    ~H"""
    <div class="submission-section">
      <div class="submission-section-header">
        <h3>{@title}</h3>
        <div class="submission-section-actions">
          <a href="#" class="submission-btn">Upload</a>
          <a href="#" class="submission-btn">Download All Files</a>
        </div>
      </div>

      <div class="submission-files-table">
        <table>
          <thead>
            <tr>
              <th class="submission-file-name">FILE NAME</th>
              <th>UPLOADED</th>
              <th>TYPE</th>
              <th class="submission-file-size">SIZE</th>
              <th class="submission-file-actions"></th>
            </tr>
          </thead>
          <tbody>
            <%= for file <- @files do %>
              <tr>
                <td class="submission-file-name">
                  <a href="#" class="submission-file-link">{file.name}</a>
                </td>
                <td>{file.uploaded}</td>
                <td>{file.type}</td>
                <td class="submission-file-size">{file.size}</td>
                <td class="submission-file-actions">
                  <button type="button" class="submission-ellipsis" onclick="toggleRowMenu(this)">
                    <span>&#8942;</span>
                  </button>
                  <div class="submission-row-menu">
                    <a href="#">Download</a>
                    <a href="#">Edit</a>
                    <a href="#">Remove</a>
                  </div>
                </td>
              </tr>
            <% end %>
            <%= if @files == [] do %>
              <tr>
                <td colspan="5" class="wf-empty">No files have been uploaded.</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :discussions, :list, default: []
  attr :add_label, :string, default: "Add Discussion"

  def workflow_discussions(assigns) do
    ~H"""
    <div class="submission-section">
      <div class="submission-section-header">
        <h3>{@title}</h3>
        <div class="submission-section-actions">
          <a href="#" class="submission-btn">{@add_label}</a>
        </div>
      </div>

      <div class="submission-discussions-table">
        <table>
          <thead>
            <tr>
              <th>NAME</th>
              <th>FROM</th>
              <th>PREVIOUS REPLY</th>
              <th>REPLIES</th>
              <th>CLOSED</th>
            </tr>
          </thead>
          <tbody>
            <%= for discussion <- @discussions do %>
              <tr>
                <td class="submission-discussion-name"><a href="#">{discussion.name}</a></td>
                <td>{discussion.from}</td>
                <td class="submission-discussion-preview">{discussion.previous_reply}</td>
                <td>{discussion.replies}</td>
                <td>
                  <%= if discussion.closed do %>
                    <span class="wf-closed">Closed</span>
                  <% else %>
                    <span class="wf-open">Open</span>
                  <% end %>
                </td>
              </tr>
            <% end %>
            <%= if @discussions == [] do %>
              <tr>
                <td colspan="5" class="wf-empty">No discussions have been started.</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :section_title, :string, required: true
  attr :submission, :map, required: true
  slot :inner_block, required: true

  def publication_section_page(assigns) do
    ~H"""
    <div class="submission-main-content">
      <div class="publication-page">
        <div class="publication-page-heading">
          <h2>{@section_title}</h2>
          <span class="submission-workflow-label">Publication</span>
        </div>

        <div class="publication-status-bar">
          <div class="publication-status-left">
            <span class="publication-version-picker">
              <span class="publication-version-label">Version:</span>
              <select class="publication-select">
                <option>1 - Unscheduled</option>
              </select>
            </span>

            <span class="publication-status-pill">
              <span class="publication-status-dot"></span> Unscheduled
            </span>
          </div>

          <div class="publication-status-right">
            <span class="publication-language">
              Manuscript Language: {@submission.language}
            </span>
            <a href="#" class="publication-schedule-btn">Schedule For Publication</a>
          </div>
        </div>

        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :help, :boolean, default: false
  slot :inner_block

  def pub_field(assigns) do
    ~H"""
    <div class="pub-field">
      <label class="pub-label">
        {@label}
        <%= if @help do %>
          <button type="button" class="pub-help-icon" title="Help">?</button>
        <% end %>
      </label>
      {render_slot(@inner_block)}
    </div>
    """
  end

  def jats_xml_preview(submission) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE article PUBLIC "-//NLM//DTD JATS (Z39.96) Journal Publishing DTD v1.2 20190208//EN"
    "https://jats.nlm.nih.gov/publishing/1.2/JATS-journalpublishing1.dtd">
    <article article-type="research-article" dtd-version="1.2" xml:lang="en">
      <front>
        <journal-meta>
          <journal-id journal-id-type="publisher-id">ojs</journal-id>
          <journal-title-group>
            <journal-title>Jurnal Perang Dunia 1</journal-title>
          </journal-title-group>
        </journal-meta>
        <article-meta>
          <title-group>
            <article-title>#{submission.title || ""}</article-title>
          </title-group>
          <contrib-group>
            <contrib contrib-type="author">
              <name>
                <surname>Fauzi</surname>
                <given-names>Ahmad</given-names>
              </name>
            </contrib>
          </contrib-group>
        </article-meta>
      </front>
    </article>
    """
  end
end
