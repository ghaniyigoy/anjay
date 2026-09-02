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
  def stage_label(:initial_review), do: "Submission"
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

  # ============================================
  # Workflow view (OJS 3.5-style routing helpers)
  # ============================================

  def workflow_menu_path(submission_id, view_id, menu_key) do
    "/dashboard/editorial?workflowSubmissionId=#{submission_id}&currentViewId=#{view_id}" <>
      "&workflowMenuKey=#{menu_key}"
  end

  def workflow_action_path(submission_id) do
    "/dashboard/editorial/#{submission_id}/publication"
  end

  def wf_menu_href(:author, submission_id, _view_id, menu_key) do
    "/submission/#{submission_id}/workflow?workflowMenuKey=#{menu_key}"
  end

  def wf_menu_href(_mode, submission_id, view_id, menu_key) do
    workflow_menu_path(submission_id, view_id, menu_key)
  end

  # Menu key terdekat dengan stage submission saat ini (dipakai tombol View).
  def default_workflow_menu_for_stage(:copyediting), do: "workflow_4"
  def default_workflow_menu_for_stage(:production), do: "workflow_5"
  def default_workflow_menu_for_stage(:needs_reviews), do: "workflow_3_1"
  def default_workflow_menu_for_stage(:awaiting_reviews), do: "workflow_3_1"
  def default_workflow_menu_for_stage(:reviews_submitted), do: "workflow_3_1"
  def default_workflow_menu_for_stage(:external_review), do: "workflow_3_1"
  def default_workflow_menu_for_stage(:revisions_submitted), do: "workflow_3_1"
  def default_workflow_menu_for_stage(_stage), do: "workflow_1"

  @workflow_stage_order ["workflow_1", "workflow_3_1", "workflow_4", "workflow_5"]

  def workflow_stage_state(menu_key, submission_stage) do
    current_idx = Enum.find_index(@workflow_stage_order, &(&1 == menu_key))

    active_idx =
      Enum.find_index(
        @workflow_stage_order,
        &(&1 == default_workflow_menu_for_stage(submission_stage))
      )

    cond do
      is_nil(current_idx) or is_nil(active_idx) -> "upcoming"
      current_idx < active_idx -> "completed"
      current_idx == active_idx -> "active"
      true -> "upcoming"
    end
  end

  def workflow_status_label(:active), do: "In Submission"
  def workflow_status_label(status), do: stage_label(status)

  # ============================================
  # Editorial activity actions (per-row in table)
  # ============================================

  def editorial_actions(row) do
    cond do
      not row.has_editor ->
        %{
          label: "Assign Editor",
          href: "#",
          modal: "assign-editor-#{row.id}"
        }

      row.needs_submission_complete ->
        %{
          label: "Complete Submission",
          href: workflow_menu_path(row.id, "assigned-to-me", "workflow_1")
        }

      row.stage in [:initial_review, :external_review] and not row.has_reviewers ->
        %{
          label: "Assign Reviewers",
          href: "#",
          modal: "assign-reviewers-#{row.id}"
        }

      true ->
        next = next_action_for_stage(row.stage)

        %{
          label: next.label,
          href: workflow_menu_path(row.id, "active", next.menu)
        }
    end
  end

  defp next_action_for_stage(:initial_review),
    do: %{label: "Send for Review", menu: "workflow_3_1"}

  defp next_action_for_stage(:external_review), do: %{label: "View Reviews", menu: "workflow_3_1"}
  defp next_action_for_stage(:needs_reviews), do: %{label: "View Reviews", menu: "workflow_3_1"}

  defp next_action_for_stage(:awaiting_reviews),
    do: %{label: "View Reviews", menu: "workflow_3_1"}

  defp next_action_for_stage(:reviews_submitted),
    do: %{label: "View Reviews", menu: "workflow_3_1"}

  defp next_action_for_stage(:revisions_submitted),
    do: %{label: "View Reviews", menu: "workflow_3_1"}

  defp next_action_for_stage(:copyediting), do: %{label: "Copyedit", menu: "workflow_4"}
  defp next_action_for_stage(:production), do: %{label: "Production", menu: "workflow_5"}
  defp next_action_for_stage(_stage), do: %{label: "Send for Review", menu: "workflow_3_1"}

  def workflow_status_class(status) when status in [:scheduled, :published], do: "wf-status-ok"
  def workflow_status_class(:declined), do: "wf-status-danger"
  def workflow_status_class(_status), do: "wf-status-info"

  def reviewer_status_label(:action_required), do: "Awaiting Review"
  def reviewer_status_label(:completed), do: "Review Completed"
  def reviewer_status_label(:declined), do: "Declined"
  def reviewer_status_label(:published), do: "Published"
  def reviewer_status_label(:archived), do: "Archived"
  def reviewer_status_label(_status), do: "In Progress"

  def reviewer_recommendation(nil), do: "—"

  def reviewer_recommendation(rec) when is_binary(rec) do
    rec |> String.replace("_", " ") |> String.capitalize()
  end

  def reviewer_recommendation(rec), do: to_string(rec)

  def latest_reviewer(assignment) do
    case assignment.review_history do
      [] -> if(assignment.reviewer_name in [nil, ""], do: nil, else: assignment.reviewer_name)
      history -> history |> List.last() |> Map.get(:reviewer)
    end
  end

  def format_date(%Date{} = date), do: Calendar.strftime(date, "%Y-%m-%d")
  def format_date(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d")
  def format_date(_other), do: "—"

  # ============================================
  # Editorial activity log (derived from store data)
  # ============================================

  def activity_events(submission, assignments) do
    created = [
      %{
        kind: :info,
        title: "Submission started",
        detail: "Author account: #{submission.author_username}",
        date: as_date(Map.get(submission, :created_at))
      }
    ]

    file_events =
      Enum.map(submission.files || [], fn file ->
        %{
          kind: :file,
          title: "File uploaded",
          detail: "#{Map.get(file, :filename)} (#{Map.get(file, :genre) || "Article Text"})",
          date: as_date(Map.get(file, :date))
        }
      end)

    submitted =
      case Map.get(submission, :date_submitted) do
        nil ->
          []

        date ->
          [
            %{
              kind: :status,
              title: "Submitted to journal",
              detail: "Current status: #{workflow_status_label(submission.status)}",
              date: as_date(date)
            }
          ]
      end

    (created ++ file_events ++ submitted ++ Enum.flat_map(assignments, &assignment_events/1))
    |> Enum.sort_by(&(&1.date || ~D[1970-01-01]), {:desc, Date})
  end

  def activity_kind_label(:file), do: "Files"
  def activity_kind_label(:review), do: "Review"
  def activity_kind_label(:copyedit), do: "Copyediting"
  def activity_kind_label(:production), do: "Production"
  def activity_kind_label(:status), do: "Status"
  def activity_kind_label(_kind), do: "Info"

  defp assignment_events(assignment) do
    assigned = [
      %{
        kind: :review,
        title: "Review round #{assignment.round || 1} opened",
        detail:
          if(is_nil(assignment.due_date),
            do: nil,
            else: "Review due #{format_date(assignment.due_date)}"
          ),
        date: as_date(assignment.date_assigned)
      }
    ]

    history =
      Enum.map(assignment.review_history || [], fn h ->
        %{
          kind: :review,
          title: "Review submitted (round #{h.round})",
          detail: "#{h.reviewer} — recommendation: #{reviewer_recommendation(h.decision)}",
          date: as_date(h.date)
        }
      end)

    copyedit =
      (assignment.copyedit_tasks || [])
      |> Enum.filter(& &1.done)
      |> Enum.map(
        &%{kind: :copyedit, title: "Copyediting complete: #{&1.label}", detail: nil, date: nil}
      )

    galleys =
      Enum.map(assignment.galley_files || [], fn galley ->
        %{
          kind: :production,
          title: "Galley prepared",
          detail: "#{galley.name} (#{galley.type})",
          date: as_date(galley.date)
        }
      end)

    proofread =
      (assignment.proofread_tasks || [])
      |> Enum.filter(& &1.done)
      |> Enum.map(
        &%{
          kind: :production,
          title: "Proofreading complete: #{&1.label}",
          detail: nil,
          date: nil
        }
      )

    published =
      case assignment.published_at do
        %DateTime{} = datetime ->
          [
            %{
              kind: :status,
              title: "Published",
              detail: if(is_nil(assignment.issue), do: nil, else: "Issue: #{assignment.issue}"),
              date: DateTime.to_date(datetime)
            }
          ]

        _published_at ->
          []
      end

    assigned ++ history ++ copyedit ++ galleys ++ proofread ++ published
  end

  defp as_date(%DateTime{} = datetime), do: DateTime.to_date(datetime)
  defp as_date(%Date{} = date), do: date

  defp as_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _reason} -> nil
    end
  end

  defp as_date(_value), do: nil

  def contributor_display(contributor) when is_map(contributor) do
    name =
      String.trim(
        "#{Map.get(contributor, :given_name) || ""} #{Map.get(contributor, :family_name) || ""}"
      )

    name = if name == "", do: Map.get(contributor, :full_name) || "Unnamed", else: name

    email = Map.get(contributor, :email)
    if is_binary(email) and email != "", do: %{name: name, email: email}, else: %{name: name}
  end

  def contributor_initials(name) when is_binary(name) do
    name
    |> String.split(~r{\s+}, trim: true)
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.map_join("", &String.upcase(&1 || ""))
  end

  # ============================================
  # JATS XML preview (publication_jats tab)
  # ============================================

  def jats_xml(submission) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE article PUBLIC "-//NLM//DTD JATS (Z39.96) Journal Archiving DTD v1.2 20190208//EN" "JATS-archivearticle1.dtd">
    <article xmlns:xlink="http://www.w3.org/1999/xlink" article-type="research-article" xml:lang="#{xml_lang(submission.language)}">
      <front>
        <journal-meta>
          <journal-id journal-id-type="publisher-id">jpd1</journal-id>
          <journal-title-group>
            <journal-title>Jurnal Perang Dunia 1</journal-title>
          </journal-title-group>
          <issn>2721-4869</issn>
        </journal-meta>
        <article-meta>
          <article-id pub-id-type="publisher-id">#{submission.id}</article-id>
          <article-categories><subj-group subj-group-type="heading"><subject>#{xml_escape(submission.section || "Articles")}</subject></subj-group></article-categories>
          <title-group>#{jats_title(submission)}</title-group>
          <contrib-group>#{jats_contributors(submission.contributors)}</contrib-group>
          <abstract><p>#{xml_escape(submission.abstract || "")}</p></abstract>
          <kwd-group kwd-group-type="author-generated">#{jats_keywords(submission.keywords)}</kwd-group>
        </article-meta>
      </front>
      <back>#{jats_references(submission.references)}</back>
    </article>\
    """
  end

  defp xml_lang(nil), do: "en"

  defp xml_lang(lang) when is_binary(lang) do
    if lang =~ ~r/indonesia/i, do: "id", else: "en"
  end

  defp xml_lang(_), do: "en"

  defp jats_title(submission) do
    subtitle = submission.subtitle

    title_tag = "<article-title>#{xml_escape(submission.title || "")}</article-title>"

    if is_binary(subtitle) and subtitle != "" do
      "#{title_tag}<subtitle>#{xml_escape(subtitle)}</subtitle>"
    else
      title_tag
    end
  end

  defp jats_contributors(contributors) when is_list(contributors) and contributors != [] do
    Enum.map_join(contributors, "\n", fn c ->
      info = contributor_display(c)
      given = Map.get(c, :given_name) || ""
      family = Map.get(c, :family_name) || ""

      """
          <contrib contrib-type="author">
            <name><surname>#{xml_escape(family)}</surname><given-names>#{xml_escape(given)}</given-names></name>
            <string-name>#{xml_escape(info.name)}</string-name>
          </contrib>\
      """
    end)
  end

  defp jats_contributors(_contributors),
    do: "<contrib contrib-type=\"author\"><string-name>—</string-name></contrib>"

  defp jats_keywords(nil), do: ""

  defp jats_keywords(keywords) when is_binary(keywords) do
    keywords
    |> String.split(",", trim: true)
    |> Enum.map_join("\n", &("<kwd>" <> xml_escape(String.trim(&1)) <> "</kwd>"))
  end

  defp jats_keywords(_), do: ""

  defp jats_references(nil), do: ""

  defp jats_references(references) when is_binary(references) do
    refs =
      references
      |> String.split(["\n", ";"], trim: true)
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {ref, idx} ->
        "<ref id=\"b#{idx}\"><mixed-citation>#{xml_escape(String.trim(ref))}</mixed-citation></ref>"
      end)

    if refs == "", do: "", else: "<ref-list>\n#{refs}\n</ref-list>"
  end

  defp jats_references(_), do: ""

  defp xml_escape(value) when is_binary(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp xml_escape(value), do: value |> to_string() |> xml_escape()
end
