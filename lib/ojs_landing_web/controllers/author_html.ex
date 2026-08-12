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
    |> Calendar.strftime("%e %b %Y")
    |> String.trim()
  end

  def format_date(%Date{} = date) do
    date
    |> Calendar.strftime("%e %b %Y")
    |> String.trim()
  end

  def format_date(_), do: "—"

  # --- Dashboard views ------------------------------------------------------

  def view_label(views, id) do
    case Enum.find(views, &(&1.id == id)) do
      nil -> "My Submissions"
      view -> view.label
    end
  end

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
      "language" => submission.language || "id"
    })
  end

  def submission_form_action(submission, tab),
    do: "/submission/wizard/#{submission.id}?tab=#{tab}"

  def file_count(submission), do: length(submission.files || [])
  def contributors_count(submission), do: length(submission.contributors || [])
  def editors_count(submission), do: length(submission.editors || [])

  def short_name(%{family_name: name}) when name not in [nil, ""], do: name
  def short_name(%{given_name: name}), do: name
  def short_name(_), do: "?"

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

  # --- Private --------------------------------------------------------------

  defp tab_done?("details", submission),
    do: is_binary(submission.title) and submission.title != ""

  defp tab_done?("files", submission), do: length(submission.files || []) > 0

  defp tab_done?("contributors", submission), do: length(submission.contributors || []) > 0

  defp tab_done?("editors", submission), do: length(submission.editors || []) > 0

  defp tab_done?("review", submission) do
    tab_done?("details", submission) and tab_done?("files", submission) and
      tab_done?("contributors", submission)
  end
end
