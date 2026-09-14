defmodule OjsLandingWeb.AuthorHTML do
  use OjsLandingWeb, :html

  embed_templates "author_html/*"

  # --- Status helpers -------------------------------------------------------

  def status_badge(:active), do: "badge-active"
  def status_badge(:revisions_requested), do: "badge-warning"
  def status_badge(:revisions_submitted), do: "badge-info"
  def status_badge(:incomplete), do: "badge-incomplete"
  def status_badge(:scheduled), do: "badge-scheduled"
  def status_badge(:published), do: "badge-success"
  def status_badge(:declined), do: "badge-danger"
  def status_badge(_), do: ""

  def status_class(:active), do: "active"
  def status_class(:revisions_requested), do: "revisions-requested"
  def status_class(:revisions_submitted), do: "revisions-submitted"
  def status_class(:incomplete), do: "incomplete"
  def status_class(:scheduled), do: "scheduled"
  def status_class(:published), do: "published"
  def status_class(:declined), do: "declined"
  def status_class(_), do: ""

  def status_text(:active), do: "Active"
  def status_text(:revisions_requested), do: "Revisions Requested"
  def status_text(:revisions_submitted), do: "Revisions Submitted"
  def status_text(:incomplete), do: "Incomplete"
  def status_text(:scheduled), do: "Scheduled for Publication"
  def status_text(:published), do: "Published"
  def status_text(:declined), do: "Declined"
  def status_text(_), do: "Unknown"

  def status_label(status), do: status_text(status)

  def format_date(%DateTime{} = datetime) do
    datetime
    |> Calendar.strftime("%d %b %Y")
    |> trim_leading_zero_day()
  end

  def format_date(%Date{} = date) do
    date
    |> Calendar.strftime("%d %b %Y")
    |> trim_leading_zero_day()
  end

  def format_date(_), do: "—"

  defp trim_leading_zero_day("0" <> rest), do: rest
  defp trim_leading_zero_day(value), do: value

  # --- Dashboard views ------------------------------------------------------

  def view_label(views, id) do
    case Enum.find(views, &(&1.id == id)) do
      nil -> "My Submissions"
      view -> view.label
    end
  end

  # --- Editor workflow view link (stage-aware) -----------------------------

  def submission_workflow_path(submission, _view_id) do
    menu = workflow_menu_for_stage(submission.stage)
    "/submission/#{submission.id}/workflow?workflowMenuKey=#{menu}"
  end

  defp workflow_menu_for_stage(:copyediting), do: "workflow_4"
  defp workflow_menu_for_stage(:production), do: "workflow_5"
  defp workflow_menu_for_stage(:needs_reviews), do: "workflow_3_1"
  defp workflow_menu_for_stage(:awaiting_reviews), do: "workflow_3_1"
  defp workflow_menu_for_stage(:reviews_submitted), do: "workflow_3_1"
  defp workflow_menu_for_stage(:external_review), do: "workflow_3_1"
  defp workflow_menu_for_stage(:revisions_submitted), do: "workflow_3_1"
  defp workflow_menu_for_stage(_stage), do: "workflow_1"

  # --- Submission wizard (tab-driven) --------------------------------------

  def tab_class(current, tab, _submission) do
    if current == tab, do: "active", else: ""
  end

  def step_done_class(tab, submission) do
    if tab_done?(tab, submission), do: "✓", else: step_number(tab)
  end

  def step_number("details"), do: "1"
  def step_number("files"), do: "2"
  def step_number("contributors"), do: "3"
  def step_number("editors"), do: "4"
  def step_number("review"), do: "5"

  def submission_to_form(submission) do
    to_form(%{
      "title" => submission.title || "",
      "subtitle" => submission.subtitle || "",
      "abstract" => submission.abstract || "",
      "section" => submission.section || "Artikel Penelitian",
      "keywords" => submission.keywords || "",
      "language" => submission.language || "id",
      "references" => submission.references || ""
    })
  end

  def submission_params_to_form(params) do
    to_form(params, as: :submission)
  end

  def submission_form_action(submission, tab),
    do: "/submission/wizard/#{submission.id}?tab=#{tab}"

  def submission_form_action(submission, tab, view: view),
    do: "/submission/wizard/#{submission.id}?tab=#{tab}&view=#{view}"

  def submission_form_action(submission, tab, view: view, contributor_id: contributor_id),
    do:
      "/submission/wizard/#{submission.id}?tab=#{tab}&view=#{view}&contributor_id=#{contributor_id}"

  def wizard_step_title("details"), do: "Make a Submission: Details"
  def wizard_step_title("files"), do: "Make a Submission: Upload Files"
  def wizard_step_title("contributors"), do: "Make a Submission: Contributors"
  def wizard_step_title("editors"), do: "Make a Submission: For the Editor"
  def wizard_step_title("review"), do: "Make a Submission: Review"

  def wizard_step_labels do
    [
      {"details", "Details"},
      {"files", "Upload Files"},
      {"contributors", "Contributors"},
      {"editors", "For the Editor"},
      {"review", "Review"}
    ]
  end

  def wizard_step_done?(tab, submission), do: step_done_class(tab, submission) == "✓"

  def wizard_prev_tab("files"), do: "details"
  def wizard_prev_tab("contributors"), do: "files"
  def wizard_prev_tab("editors"), do: "contributors"
  def wizard_prev_tab("review"), do: "editors"
  def wizard_prev_tab(_tab), do: nil

  def file_count(submission), do: length(submission.files || [])
  def contributors_count(submission), do: length(submission.contributors || [])
  def editors_count(submission), do: length(submission.editors || [])

  def strip_html(nil), do: ""

  def strip_html(value) when is_binary(value) do
    value
    |> String.replace("<br>", " ")
    |> String.replace("<br/>", " ")
    |> String.replace("<br />", " ")
    |> String.replace("</p>", " ")
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.replace("&nbsp;", " ")
    |> String.replace(~r/<[^>]*>/, "")
    |> String.trim()
  end

  def short_name(%{family_name: name}) when name not in [nil, ""], do: name
  def short_name(%{given_name: name}), do: name
  def short_name(_), do: "?"

  def primary_contact?(contributor), do: Map.get(contributor, :primary) == true

  def display_contributors(submission, user) do
    case submission.contributors do
      list when is_list(list) and list != [] -> list
      _ -> [default_contributor(user)]
    end
  end

  def contributor_form(contributor) do
    to_form(%{
      "given_name" => Map.get(contributor, :given_name, ""),
      "family_name" => Map.get(contributor, :family_name, ""),
      "preferred_public_name" => Map.get(contributor, :preferred_public_name, ""),
      "email" => Map.get(contributor, :email, ""),
      "country" => Map.get(contributor, :country, ""),
      "bio_statement" => Map.get(contributor, :bio_statement, ""),
      "affiliation" => Map.get(contributor, :affiliation, ""),
      "role" => contributor_role_value(contributor.role),
      "primary" => to_string(contributor.primary == true),
      "public_list" => to_string(Map.get(contributor, :public_list, true) == true)
    })
  end

  def contributor_roles do
    [
      {"author", "Author"},
      {"translator", "Translator"},
      {"cover_designer", "Cover Designer"}
    ]
  end

  def contributor_role_value(:author), do: "author"
  def contributor_role_value(:translator), do: "translator"
  def contributor_role_value(:cover_designer), do: "cover_designer"
  def contributor_role_value("author"), do: "author"
  def contributor_role_value("translator"), do: "translator"
  def contributor_role_value("cover_designer"), do: "cover_designer"
  def contributor_role_value("Author"), do: "author"
  def contributor_role_value("Translator"), do: "translator"
  def contributor_role_value("Cover Designer"), do: "cover_designer"
  def contributor_role_value(_), do: "author"

  def default_contributor(user) do
    %{
      id: user.id,
      given_name: user.given_name || "Penulis",
      family_name: user.family_name || "",
      preferred_public_name: "",
      email: user.email || "",
      country: user.country || "",
      bio_statement: "",
      affiliation: user.affiliation || "",
      role: :author,
      primary: true,
      public_list: true
    }
  end

  def new_contributor(id) do
    %{
      id: id,
      given_name: "",
      family_name: "",
      preferred_public_name: "",
      email: "",
      country: "",
      bio_statement: "",
      affiliation: "",
      role: :author,
      primary: false,
      public_list: true
    }
  end

  def next_contributor_id(submission, user) do
    ids = Enum.map(display_contributors(submission, user), & &1.id)
    if ids == [], do: 1, else: Enum.max(ids) + 1
  end

  def contributor_role_label(:author), do: "Author"
  def contributor_role_label(:translator), do: "Translator"
  def contributor_role_label(:cover_designer), do: "Cover Designer"
  def contributor_role_label("author"), do: "Author"
  def contributor_role_label("translator"), do: "Translator"
  def contributor_role_label("cover_designer"), do: "Cover Designer"
  def contributor_role_label(_), do: "Author"

  # --- Start A New Submission (OJS PKP preliminary information) ------------

  @submission_checklist [
    {"Naskah belum pernah dipublikasikan sebelumnya, serta tidak sedang diajukan ke jurnal lain untuk dipertimbangkan.",
     :required},
    {"Berkas naskah diserahkan dalam format OpenOffice, Microsoft Word, RTF, atau WordPerfect.",
     :required},
    {"Dengan mengunggah naskah, saya menyatakan bahwa makalah ini bebas dari praktik plagiarisme dan mengikuti panduan integritas ilmiah jurnal.",
     :required},
    {"Teks mengikuti ketentuan gaya dan bibliografi pada Panduan Penulis (halaman Tentang Jurnal, Fokus & Ruang Lingkup).",
     :required},
    {"Di mana tersedia, URL untuk referensi telah disediakan.", :optional},
    {"Berkas pendukung (gambar, tabel, instrumen penelitian) telah disiapkan dan diberi label dengan jelas.",
     :optional}
  ]

  def submission_checklist, do: @submission_checklist

  def tab_label("details"), do: "Details"
  def tab_label("files"), do: "Files"
  def tab_label("contributors"), do: "Contributors"
  def tab_label("editors"), do: "Editors"
  def tab_label("review"), do: "Review"

  # --- Make a Submission: Details (OJS 3.5 wizard) -------------------------

  @details_steps [
    %{number: "1", label: "Details"},
    %{number: "2", label: "Upload Files"},
    %{number: "3", label: "Contributors"},
    %{number: "4", label: "For the Editors"},
    %{number: "5", label: "Review"}
  ]

  def details_steps, do: @details_steps

  def step_is_current?(index), do: index == 0

  def tab_count("files", submission), do: count_or_nil(file_count(submission))
  def tab_count("contributors", submission), do: count_or_nil(contributors_count(submission))
  def tab_count("editors", submission), do: count_or_nil(editors_count(submission))
  def tab_count(_tab, _submission), do: nil

  # --- Private --------------------------------------------------------------

  defp count_or_nil(0), do: nil
  defp count_or_nil(count), do: count

  defp tab_done?("details", submission),
    do: is_binary(submission.title) and submission.title != ""

  defp tab_done?("files", submission), do: length(submission.files || []) > 0

  defp tab_done?("contributors", submission), do: length(submission.contributors || []) > 0

  defp tab_done?("editors", submission) do
    is_binary(submission.editor_comments) and submission.editor_comments != ""
  end

  defp tab_done?("review", submission) do
    submission.status != :incomplete
  end
end
