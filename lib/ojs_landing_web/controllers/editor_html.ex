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

  # Static list of issues offered by the "Schedule For Publication" modal.
  def schedule_issues do
    [
      {"Select an issue...", ""},
      {"Vol. 1, No. 1 (2026) - Forthcoming", "1"},
      {"Vol. 1, No. 2 (2026) - Forthcoming", "2"},
      {"Vol. 2, No. 1 (2026) - Forthcoming", "3"}
    ]
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
          <button
            type="button"
            class="submission-header-btn"
            onclick="openModal('activityModal')"
          >
            Activity Log
          </button>
          <button
            type="button"
            class="submission-header-btn"
            onclick="openModal('libraryModal')"
          >
            Library
          </button>
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

    <%!-- Activity Log & Notes modal --%>
    <div class="ojs-modal-overlay" id="activityModal">
      <div class="ojs-modal ojs-modal-lg">
        <div class="ojs-modal-header">
          <h2>Activity Log</h2>
          <button
            type="button"
            class="ojs-modal-close"
            onclick="closeModal('activityModal')"
            aria-label="Close"
          >
            &times;
          </button>
        </div>

        <div class="ojs-modal-tabs">
          <button
            type="button"
            class="ojs-modal-tab active"
            data-tab="activityTab"
            onclick="switchTab(this, 'activityTab')"
          >
            Activity Log
          </button>
          <button
            type="button"
            class="ojs-modal-tab"
            data-tab="notesTab"
            onclick="switchTab(this, 'notesTab')"
          >
            Notes
          </button>
        </div>

        <div class="ojs-modal-body">
          <div class="ojs-tab-panel" id="activityTab">
            <table class="ojs-activity-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>User</th>
                  <th>Event</th>
                </tr>
              </thead>
              <tbody>
                <%= for log <- @submission.activity_log do %>
                  <tr class="ojs-activity-row" onclick="toggleActivityDetail(this)">
                    <td>{log.date}</td>
                    <td>{log.user}</td>
                    <td>
                      <span class="ojs-activity-event">{log.event}</span>
                      <span class="ojs-activity-caret">&#9662;</span>
                    </td>
                  </tr>
                  <%= if log.details && log.details != [] do %>
                    <tr class="ojs-activity-detail" style="display:none;">
                      <td colspan="3">
                        <ul class="ojs-activity-detail-list">
                          <%= for d <- log.details do %>
                            <li>{d}</li>
                          <% end %>
                        </ul>
                      </td>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>
          </div>

          <div class="ojs-tab-panel" id="notesTab" style="display:none;">
            <div class="ojs-notes-list">
              <%= if @submission.notes == [] do %>
                <div class="ojs-notes-empty">No notes available.</div>
              <% else %>
                <%= for note <- @submission.notes do %>
                  <div class="ojs-note">
                    <div class="ojs-note-meta">
                      <span class="ojs-note-author">{note.author}</span>
                      <span class="ojs-note-date">{note.date}</span>
                    </div>
                    <div class="ojs-note-text">{note.text}</div>
                  </div>
                <% end %>
              <% end %>
            </div>

            <div class="ojs-note-add">
              <label class="ojs-form-field-label" for="newNoteText">Add Entry</label>
              <textarea
                id="newNoteText"
                rows="3"
                class="ojs-textarea"
                placeholder="Write a new note..."
              ></textarea>
              <div class="ojs-note-add-actions">
                <button type="button" class="ojs-modal-primary" onclick="addNote()">Add Note</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <%!-- Submission Library modal --%>
    <div class="ojs-modal-overlay" id="libraryModal">
      <div class="ojs-modal ojs-modal-lg">
        <div class="ojs-modal-header">
          <h2>Submission Library</h2>
          <button
            type="button"
            class="ojs-modal-close"
            onclick="closeModal('libraryModal')"
            aria-label="Close"
          >
            &times;
          </button>
        </div>

        <div class="ojs-modal-toolbar">
          <button type="button" class="ojs-modal-btn" onclick="openModal('addFileModal')">
            Add File
          </button>
          <button
            type="button"
            class="ojs-modal-btn"
            onclick="toggleDocLibrary(this)"
            id="docLibraryToggle"
          >
            Document Library
          </button>
        </div>

        <div class="ojs-modal-body">
          <div class="ojs-library-doc-view" id="libraryDocView" style="display:none;">
            <p class="ojs-library-doc-text">
              The document library provides publisher-wide documents. This is a static preview.
            </p>
          </div>

          <div class="ojs-library-cats" id="libraryCatView">
            <.library_category title="Marketing" items={@submission.library.marketing} />
            <.library_category title="Permissions" items={@submission.library.permissions} />
            <.library_category title="Reports" items={@submission.library.reports} />
            <.library_category title="Other" items={@submission.library.other} />
          </div>
        </div>
      </div>
    </div>

    <%!-- Add File sub-modal --%>
    <div class="ojs-modal-overlay" id="addFileModal">
      <div class="ojs-modal ojs-modal-md">
        <div class="ojs-modal-header">
          <h2>Add File</h2>
          <button
            type="button"
            class="ojs-modal-close"
            onclick="closeModal('addFileModal')"
            aria-label="Close"
          >
            &times;
          </button>
        </div>

        <div class="ojs-modal-body">
          <div class="ojs-form-field">
            <label class="ojs-form-field-label" for="addFileName">
              Name <span class="ojs-required">*</span>
            </label>
            <input type="text" id="addFileName" class="ojs-input" placeholder="File name" />
          </div>

          <div class="ojs-form-field">
            <label class="ojs-form-field-label" for="addFileType">
              Type <span class="ojs-required">*</span>
            </label>
            <select id="addFileType" class="ojs-input">
              <option value="">Select a category...</option>
              <option value="Marketing">Marketing</option>
              <option value="Permissions">Permissions</option>
              <option value="Reports">Reports</option>
              <option value="Other">Other</option>
            </select>
          </div>

          <div class="ojs-form-field">
            <label class="ojs-form-field-label" for="addFileDesc">
              Description <span class="ojs-required">*</span>
            </label>
            <textarea id="addFileDesc" rows="2" class="ojs-textarea" placeholder="File description"></textarea>
          </div>

          <div class="ojs-form-field">
            <label class="ojs-form-field-label">Upload File</label>
            <div class="ojs-dropzone" id="addFileDropzone">
              Drag and drop a file here, or click to browse
            </div>
            <div class="ojs-note-add-actions">
              <button
                type="button"
                class="ojs-modal-primary"
                onclick="document.getElementById('addFileDropzone').click(); void 0;"
              >
                Upload File
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <%!-- Schedule For Publication modal --%>
    <div class="ojs-modal-overlay" id="scheduleModal">
      <div class="ojs-modal ojs-modal-md">
        <div class="ojs-modal-header">
          <h2>Schedule For Publication</h2>
          <button
            type="button"
            class="ojs-modal-close"
            onclick="closeModal('scheduleModal')"
            aria-label="Close"
          >
            &times;
          </button>
        </div>

        <div class="ojs-modal-body">
          <p class="pub-hint" style={["margin-top: 0 !important"]}>
            Assign this submission to an issue for publication.
          </p>

          <div class="ojs-form-field">
            <label class="ojs-form-field-label" for="scheduleIssue">
              Issue <span class="ojs-required">*</span>
            </label>
            <select id="scheduleIssue" class="ojs-input" onchange="scheduleIssueChanged(this)">
              <%= for {label, value} <- schedule_issues() do %>
                <option value={value} selected={value == ""}>{label}</option>
              <% end %>
            </select>
          </div>

          <div class="ojs-form-field">
            <label class="ojs-form-field-label" for="scheduleSection">Section</label>
            <select id="scheduleSection" class="ojs-input">
              <%= for sec <- @submission.sections do %>
                <option selected={@submission.section == sec}>{sec}</option>
              <% end %>
            </select>
          </div>

          <div class="ojs-form-field">
            <label class="ojs-form-field-label" for="schedulePages">Pages</label>
            <input
              type="text"
              id="schedulePages"
              class="ojs-input"
              placeholder="e.g. 1-12"
              value=""
            />
          </div>

          <div class="ojs-form-field">
            <label class="ojs-form-field-label" for="scheduleDate">Date Published</label>
            <input type="date" id="scheduleDate" class="ojs-input" value="" />
            <p class="pub-hint">
              Leave empty to use the default publication date.
            </p>
          </div>

          <div class="ojs-form-field">
            <label class="ojs-checkbox-label">
              <input type="checkbox" id="scheduleNotify" checked />
              Send a notification to all participants
            </label>
          </div>

          <div class="ojs-note-add-actions">
            <button type="button" class="ojs-modal-primary" onclick="schedulePublication()">
              Schedule
            </button>
          </div>
        </div>
      </div>
    </div>

    <%!-- Send to Review modal --%>
    <div class="ojs-modal-overlay" id="sendToReviewModal">
      <div class="ojs-modal ojs-modal-sm">
        <div class="ojs-modal-header">
          <h2>Send to Review</h2>
          <button
            type="button"
            class="ojs-modal-close"
            onclick="closeModal('sendToReviewModal')"
            aria-label="Close"
          >
            &times;
          </button>
        </div>

        <div class="ojs-modal-body">
          <p class="ojs-decision-text">
            This submission will be moved to the review stage and will await reviewer
            assignment.
          </p>

          <div class="ojs-form-field">
            <label class="ojs-form-field-label" for="reviewRound">Review Round</label>
            <select id="reviewRound" class="ojs-input">
              <option>Round 1</option>
            </select>
          </div>

          <div class="ojs-note-add-actions">
            <button type="button" class="ojs-modal-primary" onclick="sendToReview()">
              Send to Review
            </button>
          </div>
        </div>
      </div>
    </div>

    <%!-- Accept and Skip Review modal --%>
    <div class="ojs-modal-overlay" id="skipReviewModal">
      <div class="ojs-modal ojs-modal-sm">
        <div class="ojs-modal-header">
          <h2>Accept and Skip Review</h2>
          <button
            type="button"
            class="ojs-modal-close"
            onclick="closeModal('skipReviewModal')"
            aria-label="Close"
          >
            &times;
          </button>
        </div>

        <div class="ojs-modal-body">
          <p class="ojs-decision-text">
            Accepting and skipping review will move this submission directly to the
            copyediting stage.
          </p>

          <div class="ojs-note-add-actions">
            <button type="button" class="ojs-modal-primary" onclick="skipReview()">
              Accept and Skip Review
            </button>
          </div>
        </div>
      </div>
    </div>

    <%!-- Decline Submission modal --%>
    <div class="ojs-modal-overlay" id="declineModal">
      <div class="ojs-modal ojs-modal-sm">
        <div class="ojs-modal-header">
          <h2>Decline Submission</h2>
          <button
            type="button"
            class="ojs-modal-close"
            onclick="closeModal('declineModal')"
            aria-label="Close"
          >
            &times;
          </button>
        </div>

        <div class="ojs-modal-body">
          <p class="ojs-decision-text">
            Are you sure you want to decline this submission? The submission will no
            longer proceed in the editorial workflow.
          </p>

          <div class="ojs-note-add-actions">
            <button
              type="button"
              class="ojs-modal-primary ojs-modal-primary-danger"
              onclick="declineSubmission()"
            >
              Decline Submission
            </button>
          </div>
        </div>
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

      function openModal(id) {
        var el = document.getElementById(id);
        if (el) el.style.display = 'flex';
      }

      function closeModal(id) {
        var el = document.getElementById(id);
        if (el) el.style.display = 'none';
      }

      document.addEventListener('click', function (e) {
        if (e.target.classList.contains('ojs-modal-overlay')) {
          closeModal(e.target.id);
        }
      });

      function switchTab(btn, tabId) {
        var tabs = btn.parentElement.querySelectorAll('.ojs-modal-tab');
        tabs.forEach(function (t) { t.classList.remove('active'); });
        btn.classList.add('active');
        var panels = btn.closest('.ojs-modal').querySelectorAll('.ojs-tab-panel');
        panels.forEach(function (p) { p.style.display = 'none'; });
        document.getElementById(tabId).style.display = 'block';
      }

      function toggleActivityDetail(row) {
        var detail = row.nextElementSibling;
        var caret = row.querySelector('.ojs-activity-caret');
        if (detail && detail.classList.contains('ojs-activity-detail')) {
          var visible = detail.style.display === 'table-row';
          detail.style.display = visible ? 'none' : 'table-row';
          if (caret) caret.innerHTML = visible ? '&#9662;' : '&#9652;';
        }
      }

      function addNote() {
        var text = document.getElementById('newNoteText').value.trim();
        var list = document.querySelector('#notesTab .ojs-notes-list');
        var empty = list.querySelector('.ojs-notes-empty');
        if (empty) empty.remove();
        if (text === '') return;
        var note = document.createElement('div');
        note.className = 'ojs-note';
        var meta = document.createElement('div');
        meta.className = 'ojs-note-meta';
        var author = document.createElement('span');
        author.className = 'ojs-note-author';
        author.textContent = 'Editor';
        var date = document.createElement('span');
        date.className = 'ojs-note-date';
        date.textContent = new Date().toISOString().slice(0, 10);
        meta.appendChild(author);
        meta.appendChild(date);
        var body = document.createElement('div');
        body.className = 'ojs-note-text';
        body.textContent = text;
        note.appendChild(meta);
        note.appendChild(body);
        list.appendChild(note);
        document.getElementById('newNoteText').value = '';
      }

      function toggleDocLibrary(btn) {
        var doc = document.getElementById('libraryDocView');
        var cats = document.getElementById('libraryCatView');
        var showingDoc = doc.style.display !== 'none';
        doc.style.display = showingDoc ? 'none' : 'block';
        cats.style.display = showingDoc ? 'block' : 'none';
        btn.classList.toggle('active', !showingDoc);
      }

      function scheduleIssueChanged(select) {
        var msg = document.getElementById('scheduleErr');
        if (msg) msg.style.display = select.value ? 'none' : 'block';
      }

      function schedulePublication() {
        var issue = document.getElementById('scheduleIssue');
        var err = document.getElementById('scheduleErr');

        if (!issue || issue.value === '') {
          if (!err) {
            err = document.createElement('p');
            err.className = 'ojs-schedule-err';
            err.id = 'scheduleErr';
            issue.closest('.ojs-form-field').appendChild(err);
          }
          err.textContent = 'A publication issue is required.';
          err.style.display = 'block';
          return;
        }

        var label = issue.options[issue.selectedIndex].text;
        var statusPill = document.querySelector('.publication-status-pill');
        var versionSelect = document.querySelector('.publication-version-picker .publication-select');
        var statusBox = document.querySelector('.pub-status-box-text p');
        var scheduleBtn = document.querySelector('.pub-schedule-primary');

        closeModal('scheduleModal');

        if (statusPill) {
          statusPill.innerHTML = '<span class="publication-status-dot"></span> Scheduled';
        }
        if (versionSelect) {
          versionSelect.innerHTML = '<option>1 - Scheduled</option>';
        }
        if (statusBox) {
          statusBox.textContent = 'This article is scheduled for publication in ' + label + '.';
        }
        if (scheduleBtn) {
          var badge = document.createElement('span');
          badge.className = 'pub-scheduled-badge';
          badge.textContent = 'Scheduled';
          scheduleBtn.replaceWith(badge);
        }
      }

      function applyEditorialDecision(stageText, dotColor, modalId, storedMsg) {
        closeModal(modalId);

        var indicator = document.querySelector('.submission-stage-indicator');
        if (indicator) {
          var dot = indicator.querySelector('.submission-stage-dot');
          if (dot) dot.style.backgroundColor = dotColor;
          var text = indicator.cloneNode(true);
          text.querySelector('.submission-stage-dot').remove();
          text.textContent = ' ' + stageText;
          indicator.textContent = '';
          indicator.appendChild(dot);
          indicator.appendChild(text);
        }

        var actions = document.querySelector('.submission-actions');
        if (actions) {
          var done = document.createElement('div');
          done.className = 'ojs-decision-done';
          done.textContent = storedMsg;
          actions.innerHTML = '';
          actions.appendChild(done);
        }
      }

      function sendToReview() {
        applyEditorialDecision(
          'In Review',
          '#f39c12',
          'sendToReviewModal',
          'Submission sent to review.'
        );
      }

      function skipReview() {
        applyEditorialDecision(
          'Copyediting',
          '#2ecc71',
          'skipReviewModal',
          'Submission accepted and skipped review. Moved to copyediting.'
        );
      }

      function declineSubmission() {
        applyEditorialDecision(
          'Declined',
          '#c0392b',
          'declineModal',
          'Submission declined.'
        );
      }
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

  attr :title, :string, required: true
  attr :items, :list, default: []

  def library_category(assigns) do
    ~H"""
    <div class="ojs-library-cat">
      <div class="ojs-library-cat-header">
        <h3>{@title}</h3>
        <a
          href="#"
          class="ojs-library-add-link"
          onclick="openModal('addFileModal'); event.preventDefault();"
        >
          Add File
        </a>
      </div>

      <%= if @items == [] do %>
        <div class="ojs-library-no-items">No Items</div>
      <% else %>
        <table class="ojs-library-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Added</th>
              <th class="ojs-library-row-actions"></th>
            </tr>
          </thead>
          <tbody>
            <%= for item <- @items do %>
              <tr>
                <td><a href="#" class="ojs-library-item">{item.name}</a></td>
                <td>{item.added}</td>
                <td class="ojs-library-row-actions">
                  <button type="button" class="submission-ellipsis" onclick="toggleRowMenu(this)">
                    <span>&#8942;</span>
                  </button>
                  <div class="submission-row-menu">
                    <a href="#">Download</a>
                    <a href="#">Delete</a>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
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
            <button
              type="button"
              class="publication-schedule-btn"
              onclick="openModal('scheduleModal')"
            >
              Schedule For Publication
            </button>
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
