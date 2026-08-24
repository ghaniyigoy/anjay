defmodule OjsLandingWeb.SubmissionWizardLive do
  use OjsLandingWeb, :live_view

  alias OjsLanding.Submission
  alias OjsLanding.User

  @steps ["details", "files", "contributors", "editors", "review"]

  @step_titles %{
    "details" => "Make a Submission: Details",
    "files" => "Make a Submission: Upload Files",
    "contributors" => "Make a Submission: Contributors",
    "editors" => "Make a Submission: For the Editor",
    "review" => "Make a Submission: Review"
  }

  @step_labels %{
    "details" => "Details",
    "files" => "Upload Files",
    "contributors" => "Contributors",
    "editors" => "For the Editor",
    "review" => "Review"
  }

  @roles ["Author", "Translator", "Cover Designer"]

  @genres [
    "Article Text",
    "Research Instrument",
    "Research Materials",
    "Research Results",
    "Transcripts",
    "Data Analysis",
    "Data Set",
    "Source Texts",
    "Other"
  ]

  @impl true
  def mount(%{"id" => id}, session, socket) do
    username = Map.get(session, "current_user")
    user = username && User.find_by_username(username)
    submission = Submission.get(id)

    cond do
      is_nil(user) ->
        {:ok,
         socket
         |> put_flash(:error, "Silakan login terlebih dahulu untuk melihat submission.")
         |> redirect(to: "/login")}

      is_nil(submission) ->
        {:ok,
         socket
         |> put_flash(:error, "Submission tidak ditemukan.")
         |> redirect(to: "/dashboard/mySubmissions")}

      true ->
        contributors = build_contributors(submission, user)

        primary_contact_id =
          Enum.find_value(contributors, nil, &if(&1.corresponding, do: &1.id))

        socket =
          socket
          |> assign(
            submission: submission,
            user: user,
            steps: @steps,
            step_labels: @step_labels,
            step_titles: @step_titles,
            roles: @roles,
            genres: @genres,
            step: "details",
            page_title: @step_titles["details"],
            form: details_form(submission),
            details_errors: %{},
            saved_files: normalize_files(submission.files || []),
            editor_comments: submission.editor_comments || "",
            contributors: contributors,
            editing_contributor_id: nil,
            primary_contact_id: primary_contact_id,
            contributor_view: :list,
            contributor_order_backup: nil,
            last_saved: "Last saved 1 minute ago",
            submitted: false
          )
          |> allow_upload(:files,
            accept: ~w(.pdf .doc .docx),
            max_entries: 10,
            max_file_size: 50 * 1024 * 1024
          )

        {:ok, socket, layout: {OjsLandingWeb.Layouts, :submission_live}}
    end
  end

  @impl true
  def handle_params(%{"step" => step}, _uri, socket) when step in @steps do
    {:noreply,
     socket
     |> assign(step: step, page_title: @step_titles[step])}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, step: "details", page_title: @step_titles["details"])}
  end

  # =====================================================================
  # Details step
  # =====================================================================

  @impl true
  def handle_event("validate_details", %{"submission" => params}, socket) do
    {:noreply,
     assign(socket,
       form: to_form(details_params(params), as: :submission),
       details_errors: %{}
     )}
  end

  def handle_event("save_details", %{"submission" => params} = all, socket) do
    action = Map.get(all, "action", "continue")
    errors = validate_details(params)

    if map_size(errors) > 0 do
      {:noreply,
       assign(socket,
         form: to_form(details_params(params), as: :submission),
         details_errors: errors
       )}
    else
      socket =
        socket
        |> assign(form: to_form(details_params(params), as: :submission), details_errors: %{})
        |> persist_all()

      advance_or_save(socket, action, "files")
    end
  end

  # =====================================================================
  # Files step
  # =====================================================================

  def handle_event("upload_files", _params, socket) do
    {:noreply, consume_ready_uploads(socket)}
  end

  def handle_event("save_files", %{"action" => action}, socket) do
    socket = socket |> consume_ready_uploads() |> persist_all()
    advance_or_save(socket, action, "contributors")
  end

  def handle_event("set_file_genre", %{"id" => id, "genre" => genre}, socket)
      when genre in @genres do
    files =
      Enum.map(socket.assigns.saved_files, fn file ->
        if to_string(file.id) == id,
          do: %{file | genre: genre, genre_picker: false},
          else: file
      end)

    {:noreply, assign(socket, saved_files: files)}
  end

  def handle_event("open_genre_picker", %{"id" => id}, socket) do
    files =
      Enum.map(socket.assigns.saved_files, fn file ->
        if to_string(file.id) == id, do: %{file | genre_picker: true}, else: file
      end)

    {:noreply, assign(socket, saved_files: files)}
  end

  def handle_event("close_genre_picker", %{"id" => id}, socket) do
    files =
      Enum.map(socket.assigns.saved_files, fn file ->
        if to_string(file.id) == id, do: %{file | genre_picker: false}, else: file
      end)

    {:noreply, assign(socket, saved_files: files)}
  end

  def handle_event("edit_file", %{"id" => id}, socket) do
    files =
      Enum.map(socket.assigns.saved_files, fn file ->
        if to_string(file.id) == id, do: %{file | genre_picker: true}, else: file
      end)

    {:noreply, assign(socket, saved_files: files)}
  end

  def handle_event("remove_file", %{"id" => id}, socket) do
    files = Enum.reject(socket.assigns.saved_files, &(to_string(&1.id) == id))
    {:noreply, assign(socket, saved_files: files)}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :files, ref)}
  end

  # =====================================================================
  # Contributors step
  # =====================================================================

  def handle_event("add_contributor", _params, socket) do
    id = next_contributor_id(socket.assigns.contributors)

    contributor = %{
      id: id,
      given_name: "",
      family_name: "",
      preferred_public_name: "",
      name: "",
      email: "",
      country: "",
      bio_statement: "",
      affiliation: "",
      orcid: "",
      role: "Author",
      corresponding: false,
      public_list: true,
      editing: true
    }

    {:noreply,
     assign(socket,
       contributors: socket.assigns.contributors ++ [contributor],
       editing_contributor_id: id
     )}
  end

  def handle_event("start_edit_contributor", %{"id" => id}, socket) do
    id = String.to_integer(id)

    contributors =
      Enum.map(socket.assigns.contributors, fn c -> %{c | editing: c.id == id} end)

    {:noreply, assign(socket, contributors: contributors, editing_contributor_id: id)}
  end

  def handle_event("cancel_edit_contributor", %{"id" => id}, socket) do
    id = String.to_integer(id)

    contributors =
      Enum.map(socket.assigns.contributors, fn c ->
        if c.id == id, do: %{c | editing: false}, else: c
      end)

    {:noreply, assign(socket, contributors: contributors, editing_contributor_id: nil)}
  end

  def handle_event("save_contributor", %{"contributor" => params}, socket) do
    {contributors, primary_contact_id} =
      apply_contributor_params(
        socket.assigns.contributors,
        params,
        socket.assigns.primary_contact_id
      )

    {:noreply,
     assign(socket,
       contributors: Enum.map(contributors, &%{&1 | editing: false}),
       editing_contributor_id: nil,
       primary_contact_id: primary_contact_id
     )}
  end

  def handle_event("update_contributor", %{"contributor" => params}, socket) do
    {contributors, primary_contact_id} =
      apply_contributor_params(
        socket.assigns.contributors,
        params,
        socket.assigns.primary_contact_id
      )

    {:noreply,
     assign(socket,
       contributors: contributors,
       primary_contact_id: primary_contact_id
     )}
  end

  def handle_event("delete_contributor", %{"id" => id}, socket) do
    id = String.to_integer(id)

    contributors = Enum.reject(socket.assigns.contributors, &(&1.id == id))

    primary_contact_id =
      if socket.assigns.primary_contact_id == id,
        do: nil,
        else: socket.assigns.primary_contact_id

    {:noreply, assign(socket, contributors: contributors, primary_contact_id: primary_contact_id)}
  end

  def handle_event("set_primary_contact", %{"id" => id}, socket) do
    id = String.to_integer(id)

    contributors =
      Enum.map(socket.assigns.contributors, fn c -> %{c | corresponding: c.id == id} end)

    {:noreply, assign(socket, contributors: contributors, primary_contact_id: id)}
  end

  def handle_event("toggle_order", _params, socket) do
    view = if socket.assigns.contributor_view == :order, do: :list, else: :order

    backup =
      if socket.assigns.contributor_view == :order do
        socket.assigns.contributor_order_backup
      else
        socket.assigns.contributors
      end

    {:noreply, assign(socket, contributor_view: view, contributor_order_backup: backup)}
  end

  def handle_event("save_order", _params, socket) do
    {:noreply, assign(socket, contributor_view: :list, contributor_order_backup: nil)}
  end

  def handle_event("cancel_order", _params, socket) do
    contributors = socket.assigns.contributor_order_backup || socket.assigns.contributors

    {:noreply,
     assign(socket,
       contributors: contributors,
       contributor_view: :list,
       contributor_order_backup: nil
     )}
  end

  def handle_event("toggle_preview", _params, socket) do
    view = if socket.assigns.contributor_view == :preview, do: :list, else: :preview
    {:noreply, assign(socket, contributor_view: view)}
  end

  def handle_event("move_contributor", %{"id" => id, "dir" => dir}, socket) do
    id = String.to_integer(id)
    contributors = move_contributor(socket.assigns.contributors, id, dir)
    {:noreply, assign(socket, contributors: contributors)}
  end

  def handle_event("save_contributors", %{"action" => action}, socket) do
    socket = persist_all(socket)
    advance_or_save(socket, action, "editors")
  end

  # =====================================================================
  # For the Editor step
  # =====================================================================

  def handle_event("save_editors", %{"submission" => params} = all, socket) do
    action = Map.get(all, "action", "continue")
    comments = Map.get(params, "editor_comments", "") || ""

    socket =
      socket
      |> assign(editor_comments: comments)
      |> persist_all()

    advance_or_save(socket, action, "review")
  end

  # =====================================================================
  # Review step
  # =====================================================================

  def handle_event("go_to_step", %{"step" => step}, socket) when step in @steps do
    socket = persist_all(socket)
    {:noreply, push_patch(socket, to: wizard_path(socket.assigns.submission.id, step))}
  end

  def handle_event("save_review", %{"action" => action}, socket) do
    socket = persist_all(socket)
    advance_or_save(socket, action, nil)
  end

  def handle_event("submit_submission", _params, socket) do
    socket = persist_all(socket)
    Submission.set_status(socket.assigns.submission.id, :active)

    {:noreply, assign(socket, submitted: true, page_title: "Submission Received")}
  end

  def handle_event("save_for_later", _params, socket) do
    socket = persist_all(socket)

    {:noreply,
     redirect(socket, to: "/dashboard/mySubmissions?currentViewId=incomplete-submissions")}
  end

  # =====================================================================
  # Shared helpers
  # =====================================================================

  defp advance_or_save(socket, "save", _next_step) do
    {:noreply,
     redirect(socket, to: "/dashboard/mySubmissions?currentViewId=incomplete-submissions")}
  end

  defp advance_or_save(socket, _action, next_step) when is_binary(next_step) do
    {:noreply, push_patch(socket, to: wizard_path(socket.assigns.submission.id, next_step))}
  end

  defp advance_or_save(socket, _action, _next_step), do: {:noreply, socket}

  defp consume_ready_uploads(socket) do
    case uploaded_entries(socket, :files) do
      {done, []} when done != [] ->
        new_files = consume_uploaded_entries(socket, :files, &file_entry_result/2)
        assign(socket, saved_files: socket.assigns.saved_files ++ new_files)

      _ ->
        socket
    end
  end

  defp file_entry_result(_meta, entry) do
    {:ok,
     %{
       id: entry.ref,
       name: entry.client_name,
       size: format_size(entry.client_size),
       genre: nil,
       genre_picker: false,
       date: date_string()
     }}
  end

  defp persist_all(socket) do
    submission = socket.assigns.submission

    details = %{
      "title" => socket.assigns.form["title"].value,
      "keywords" => socket.assigns.form["keywords"].value,
      "abstract" => socket.assigns.form["abstract"].value,
      "references" => socket.assigns.form["references"].value
    }

    params =
      details
      |> Map.merge(%{
        "files" => files_to_persist(socket.assigns.saved_files),
        "contributors" => contributors_to_persist(socket.assigns.contributors),
        "editor_comments" => socket.assigns.editor_comments
      })

    Submission.update(submission.id, params)
    socket
  end

  defp files_to_persist(files) do
    Enum.map(files, fn file ->
      %{
        id: file.id,
        filename: file.name,
        genre: file.genre || "",
        size: file.size,
        date: file.date
      }
    end)
  end

  defp contributors_to_persist(contributors) do
    Enum.map(contributors, fn c ->
      %{
        id: c.id,
        given_name: c.given_name,
        family_name: c.family_name,
        preferred_public_name: c.preferred_public_name,
        email: c.email,
        country: c.country,
        bio_statement: c.bio_statement,
        affiliation: c.affiliation,
        orcid: c.orcid,
        role: String.downcase(String.replace(c.role, " ", "_")),
        primary: c.corresponding,
        public_list: c.public_list
      }
    end)
  end

  defp validate_details(params) do
    %{}
    |> maybe_add_error("title", "A title is required.", params["title"])
    |> maybe_add_error("abstract", "An abstract is required.", strip_html(params["abstract"]))
  end

  defp maybe_add_error(errors, _key, _message, value) when not is_binary(value), do: errors

  defp maybe_add_error(errors, key, message, value) do
    if String.trim(value) == "", do: Map.put(errors, key, message), else: errors
  end

  defp strip_html(nil), do: ""

  defp strip_html(html) when is_binary(html) do
    html
    |> String.replace(~r/<[^>]*>/u, "")
    |> String.replace(~r/&nbsp;|&#160;/u, " ")
    |> String.trim()
  end

  defp details_params(params) do
    %{
      "title" => params["title"] || "",
      "keywords" => params["keywords"] || "",
      "abstract" => params["abstract"] || "",
      "references" => params["references"] || ""
    }
  end

  defp details_form(submission) do
    to_form(
      %{
        "title" => submission.title || "",
        "keywords" => submission.keywords || "",
        "abstract" => submission.abstract || "",
        "references" => submission.references || ""
      },
      as: :submission
    )
  end

  defp normalize_files(files) when is_list(files) do
    files
    |> Enum.with_index(1)
    |> Enum.map(fn {file, index} ->
      %{
        id: Map.get(file, :id) || index,
        name: Map.get(file, :filename) || Map.get(file, :name) || "file-#{index}",
        genre: normalize_genre(Map.get(file, :genre)),
        genre_picker: false,
        size: Map.get(file, :size) || "",
        date: Map.get(file, :date) || ""
      }
    end)
  end

  defp normalize_genre(genre) when genre in ["main article", "other", nil, ""], do: genre
  defp normalize_genre(genre) when is_binary(genre), do: genre
  defp normalize_genre(_), do: nil

  defp build_contributors(%{contributors: contributors}, _user) when length(contributors) > 0 do
    contributors
    |> Enum.with_index(1)
    |> Enum.map(fn {c, index} ->
      %{
        id: Map.get(c, :id) || index,
        given_name: Map.get(c, :given_name) || "",
        family_name: Map.get(c, :family_name) || "",
        preferred_public_name: Map.get(c, :preferred_public_name) || "",
        name: contributor_name(c, index),
        email: Map.get(c, :email) || "",
        country: Map.get(c, :country) || "",
        bio_statement: Map.get(c, :bio_statement) || "",
        affiliation: Map.get(c, :affiliation) || "",
        orcid: Map.get(c, :orcid) || "",
        role: contributor_role(c),
        corresponding: Map.get(c, :primary) == true || Map.get(c, :corresponding) == true,
        public_list: Map.get(c, :public_list) != false,
        editing: false
      }
    end)
  end

  defp build_contributors(_submission, user) do
    [
      %{
        id: 1,
        given_name: user.given_name || "",
        family_name: user.family_name || "",
        preferred_public_name: "",
        name: default_author_name(user),
        email: user.email || "",
        country: "",
        bio_statement: "",
        affiliation: "",
        orcid: "",
        role: "Author",
        corresponding: true,
        public_list: true,
        editing: false
      }
    ]
  end

  defp contributor_name(c, index) do
    given = Map.get(c, :given_name) || ""
    family = Map.get(c, :family_name) || ""

    case String.trim("#{given} #{family}") do
      "" -> "Contributor #{index}"
      name -> name
    end
  end

  defp contributor_role(c) do
    role = Map.get(c, :role)

    case role do
      role when role in @roles -> role
      :author -> "Author"
      :translator -> "Translator"
      :cover_designer -> "Cover Designer"
      "author" -> "Author"
      "translator" -> "Translator"
      "cover_designer" -> "Cover Designer"
      _ -> "Author"
    end
  end

  defp default_author_name(user) do
    given = user.given_name || ""
    family = user.family_name || ""

    case String.trim("#{given} #{family}") do
      "" -> "John Doe"
      name -> name
    end
  end

  defp next_contributor_id(contributors) do
    ids = Enum.map(contributors, & &1.id)
    if(ids == [], do: 0, else: Enum.max(ids)) + 1
  end

  defp move_contributor(contributors, id, dir) do
    index = Enum.find_index(contributors, &(&1.id == id))

    if is_nil(index) do
      contributors
    else
      swap_index =
        case dir do
          "up" when index > 0 -> index - 1
          "down" when index < length(contributors) - 1 -> index + 1
          _ -> index
        end

      List.replace_at(contributors, index, Enum.at(contributors, swap_index))
      |> List.replace_at(swap_index, Enum.at(contributors, index))
    end
  end

  defp apply_contributor_params(contributors, params, primary_contact_id) do
    id = String.to_integer(params["id"])
    corresponding = params["corresponding"] in ["true", "on", "1"]
    public_list = params["public_list"] in ["true", "on", "1"]

    contributors =
      Enum.map(contributors, fn c ->
        if c.id == id do
          given = params["given_name"] || ""
          family = params["family_name"] || ""

          %{
            c
            | given_name: given,
              family_name: family,
              preferred_public_name: params["preferred_public_name"] || "",
              name: String.trim("#{given} #{family}"),
              email: params["email"] || "",
              country: params["country"] || "",
              bio_statement: params["bio_statement"] || "",
              affiliation: params["affiliation"] || "",
              orcid: params["orcid"] || "",
              role: params["role"] || c.role,
              corresponding: c.corresponding || corresponding,
              public_list: public_list
          }
        else
          if corresponding, do: %{c | corresponding: false}, else: c
        end
      end)

    primary_contact_id = if corresponding, do: id, else: primary_contact_id
    {contributors, primary_contact_id}
  end

  defp format_size(size) when is_integer(size) and size >= 1024 * 1024 do
    "#{Float.round(size / 1024 / 1024, 1)} MB"
  end

  defp format_size(size) when is_integer(size) and size >= 1024, do: "#{round(size / 1024)} KB"
  defp format_size(size) when is_integer(size), do: "#{size} B"
  defp format_size(_), do: ""

  defp date_string do
    DateTime.utc_now()
    |> Calendar.strftime("%Y-%m-%d")
  end

  # --- Template helpers ---------------------------------------------------

  def wizard_path(id, step), do: "/submission/#{id}/wizard/#{step}"

  def prev_step(step) do
    case Enum.find_index(@steps, &(&1 == step)) do
      nil -> nil
      0 -> nil
      index -> Enum.at(@steps, index - 1)
    end
  end

  def step_done?(step, current_step) do
    step_index = Enum.find_index(@steps, &(&1 == step)) || 0
    current_index = Enum.find_index(@steps, &(&1 == current_step)) || 0
    step_index < current_index
  end

  def file_genre_label("main article"), do: "Article Text"
  def file_genre_label("other"), do: "Other"
  def file_genre_label(genre) when is_binary(genre), do: genre
  def file_genre_label(_), do: ""

  def contributor_display_name(%{name: name}, _index) when is_binary(name) and name != "",
    do: name

  def contributor_display_name(_contributor, index), do: "Contributor #{index}"

  def initials(%{name: name}) when is_binary(name) and name != "" do
    name
    |> String.split(" ")
    |> Enum.reject(&(&1 == ""))
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end

  def initials(_), do: "?"

  # =====================================================================
  # Step components
  # =====================================================================

  def details_step(assigns) do
    ~H"""
    <.form for={@form} id="details-form" phx-change="validate_details" phx-submit="save_details">
      <div class="ojs-details-grid">
        <div class="ojs-details-aside">
          <h2>Submission Details</h2>
          <p>
            Please provide the following details to help us manage your submission in our system.
          </p>
        </div>

        <div class="ojs-details-form">
          <div class="ojs-field-block" id="title-field">
            <label for="title" class="ojs-field-label">
              Title <span class="ojs-req">*</span>
            </label>
            <input
              type="text"
              id="title"
              name="submission[title]"
              class={["ojs-input", @details_errors["title"] && "ojs-input-error"]}
              value={@form[:title].value}
              placeholder="Judul lengkap makalah"
              autocomplete="off"
            />
            <p class="ojs-field-error" data-error-for="title" role="alert">
              {@details_errors["title"]}
            </p>
          </div>

          <div class="ojs-field-block">
            <label for="keywords" class="ojs-field-label">Keywords</label>
            <p class="ojs-field-desc">
              Enter the keywords for this submission, separated by commas.
            </p>
            <input
              type="text"
              id="keywords"
              name="submission[keywords]"
              class="ojs-input"
              value={@form[:keywords].value}
              placeholder="machine learning, NLP, analisis sentimen"
            />
          </div>

          <div class="ojs-field-block" id="abstract-field">
            <label class="ojs-field-label">
              Abstract <span class="ojs-req">*</span>
            </label>
            <p class="ojs-field-desc">
              Provide a concise summary of the purpose, methods, results and conclusions of your
              research (maximum 300 words).
            </p>
            <textarea
              id="abstract"
              name="submission[abstract]"
              class="hidden"
              aria-hidden="true"
              tabindex="-1"
            >{@form[:abstract].value}</textarea>
            <div
              class="ojs-richtext-toolbar"
              id="abstract-toolbar"
              role="toolbar"
              aria-label="Formatting options"
            >
              <button type="button" data-cmd="bold" title="Bold" aria-label="Bold">
                <strong>B</strong>
              </button>
              <button type="button" data-cmd="italic" title="Italic" aria-label="Italic">
                <em>I</em>
              </button>
              <button
                type="button"
                data-cmd="superscript"
                title="Superscript"
                aria-label="Superscript"
              >
                x<sup>2</sup>
              </button>
              <button type="button" data-cmd="subscript" title="Subscript" aria-label="Subscript">
                x<sub>2</sub>
              </button>
              <button type="button" data-cmd="createLink" title="Link" aria-label="Link">
                <svg
                  width="15"
                  height="15"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"></path>
                  <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"></path>
                </svg>
              </button>
            </div>
            <div
              id="abstract-editor"
              class="ojs-richtext"
              contenteditable="true"
              phx-update="ignore"
              data-target="abstract"
              data-placeholder="Write your abstract here..."
              role="textbox"
              aria-multiline="true"
              aria-label="Abstract"
            ></div>
            <p class="ojs-field-error" data-error-for="abstract" role="alert">
              {@details_errors["abstract"]}
            </p>
          </div>

          <div class="ojs-field-block">
            <label for="references" class="ojs-field-label">References</label>
            <p class="ojs-field-desc">
              List the references cited in your submission. Include URLs for each reference where
              available.
            </p>
            <textarea
              id="references"
              name="submission[references]"
              class="ojs-textarea ojs-textarea-lg"
              rows="7"
              placeholder="1. Author, A. (Year). Title of the article. Journal Name, Volume(Issue), Pages."
            >{@form[:references].value}</textarea>
          </div>

          <%= if map_size(@details_errors) > 0 do %>
            <div class="ojs-details-alert" id="details-alert" role="alert">
              <strong>Your submission is incomplete.</strong>
              <p>Please correct the highlighted fields below before continuing.</p>
            </div>
          <% end %>
        </div>
      </div>

      <div class="ojs-details-footer">
        <div class="ojs-details-actions">
          <span class="ojs-last-saved">{@last_saved}</span>
          <.link navigate="/dashboard/mySubmissions" class="btn-ojs-link" id="btn-cancel">
            Cancel
          </.link>
          <button
            type="submit"
            name="action"
            value="save"
            class="btn-ojs-secondary"
            id="btn-save-later"
          >
            Save for Later
          </button>
          <button
            type="submit"
            name="action"
            value="continue"
            class="btn-ojs-primary"
            id="btn-continue"
          >
            Continue
          </button>
        </div>
      </div>
    </.form>
    """
  end

  def files_step(assigns) do
    ~H"""
    <.form for={@form} id="files-form" phx-change="upload_files" phx-submit="save_files">
      <div class="ojs-details-grid">
        <div class="ojs-details-aside">
          <h2>Upload Files</h2>
          <p>
            Provide any files our editorial team may need to evaluate your submission. In addition
            to the main work, you may wish to submit data sets, conflict of interest statements, or
            other supplementary files if these will be helpful for our editor.
          </p>
        </div>

        <div class="ojs-details-form">
          <div class="ojs-field-block">
            <div class="ojs-file-upload-section" id="file-upload-section">
              <div class="ojs-file-upload-header">
                <h3 class="ojs-section-title">Files</h3>
                <button type="button" class="ojs-add-file-btn" id="btn-add-file">Add File</button>
              </div>

              <div class="ojs-file-upload-body">
                <div class="ojs-dropzone" id="file-dropzone" phx-drop-target={@uploads.files.ref}>
                  <div class="ojs-dropzone-icon">
                    <svg
                      width="34"
                      height="34"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.6"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    >
                      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                      <polyline points="17 8 12 3 7 8"></polyline>
                      <line x1="12" y1="3" x2="12" y2="15"></line>
                    </svg>
                  </div>
                  <div class="ojs-dropzone-text">
                    <strong>Upload any files the editorial team will need to evaluate your submission.</strong>
                    <span class="ojs-upload-file-link" id="upload-file-link">Upload File</span>
                  </div>
                  <.live_file_input
                    upload={@uploads.files}
                    id="file-input"
                    class="ojs-dropzone-input"
                  />
                  <div class="ojs-dropzone-hint">PDF, DOC, DOCX. Up to 10 files, max 50 MB each.</div>
                </div>

                <div class="ojs-dropzone-errors" id="file-errors">
                  <%= for error <- upload_errors(@uploads.files) do %>
                    <p class="ojs-field-error" role="alert">{error_to_string(error)}</p>
                  <% end %>
                </div>

                <%= for entry <- @uploads.files.entries do %>
                  <div class="ojs-upload-entry" id={"upload-entry-" <> entry.ref}>
                    <div class="ojs-upload-entry-info">
                      <span class="ojs-file-name-cell">{entry.client_name}</span>
                      <span class="ojs-upload-progress">{entry.progress}%</span>
                      <button
                        type="button"
                        class="btn-ojs-link"
                        phx-click="cancel_upload"
                        phx-value-ref={entry.ref}
                      >
                        Cancel
                      </button>
                    </div>
                    <div class="ojs-upload-track">
                      <div class="ojs-upload-bar" style={"width: #{entry.progress}%"} />
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <div class="uploaded-files-section">
            <h3 class="ojs-section-title">Uploaded Files</h3>
            <%= if @saved_files == [] do %>
              <div class="ojs-empty-state" id="no-files">No files uploaded yet.</div>
            <% else %>
              <div class="ojs-file-list" id="saved-files">
                <%= for file <- @saved_files do %>
                  <div class="ojs-file-item" id={"file-row-" <> to_string(file.id)}>
                    <div class="ojs-file-item-top">
                      <span class="ojs-file-item-name">{file.name}</span>
                      <div class="ojs-file-item-actions">
                        <button
                          type="button"
                          class="btn-ojs-link"
                          id={"edit-file-" <> to_string(file.id)}
                          phx-click="edit_file"
                          phx-value-id={file.id}
                        >
                          Edit
                        </button>
                        <button
                          type="button"
                          class="btn-ojs-link"
                          id={"remove-file-" <> to_string(file.id)}
                          phx-click="remove_file"
                          phx-value-id={file.id}
                        >
                          Remove
                        </button>
                      </div>
                    </div>

                    <div class="ojs-file-item-meta">
                      {file.size}
                      <%= if file.date != "" do %>
                        <span aria-hidden="true">·</span> {file.date}
                      <% end %>
                    </div>

                    <%= cond do %>
                      <% file.genre_picker -> %>
                        <div class="ojs-file-genre-picker" id={"genre-picker-" <> to_string(file.id)}>
                          <span class="ojs-genre-question">What kind of file is this?</span>
                          <p class="ojs-genre-desc">
                            Choose the option that best describes this file
                          </p>
                          <div class="ojs-genre-options">
                            <%= for genre <- @genres do %>
                              <button
                                type="button"
                                class={[
                                  "ojs-genre-option",
                                  file.genre == genre && "ojs-genre-option-selected"
                                ]}
                                phx-click="set_file_genre"
                                phx-value-id={file.id}
                                phx-value-genre={genre}
                              >
                                {genre}
                              </button>
                            <% end %>
                          </div>
                          <button
                            type="button"
                            class="btn-ojs-link ojs-genre-cancel"
                            id={"cancel-genre-" <> to_string(file.id)}
                            phx-click="close_genre_picker"
                            phx-value-id={file.id}
                          >
                            Cancel
                          </button>
                        </div>
                      <% is_nil(file.genre) or file.genre == "" -> %>
                        <div class="ojs-file-genre-prompt" id={"genre-prompt-" <> to_string(file.id)}>
                          <span class="ojs-genre-question">What kind of file is this?</span>
                          <div class="ojs-genre-options">
                            <button
                              type="button"
                              class="ojs-genre-option"
                              phx-click="set_file_genre"
                              phx-value-id={file.id}
                              phx-value-genre="Article Text"
                            >
                              Article Text
                            </button>
                            <button
                              type="button"
                              class="ojs-genre-option"
                              phx-click="open_genre_picker"
                              phx-value-id={file.id}
                            >
                              Other
                            </button>
                          </div>
                        </div>
                      <% true -> %>
                        <div class="ojs-file-genre-set" id={"genre-set-" <> to_string(file.id)}>
                          <span class="ojs-genre-chip">{file_genre_label(file.genre)}</span>
                        </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <div class="ojs-details-footer">
        <.link
          patch={wizard_path(@submission.id, prev_step(@step))}
          class="btn-ojs-link"
          id="btn-back"
        >
          Back
        </.link>

        <div class="ojs-details-actions">
          <span class="ojs-last-saved">{@last_saved}</span>
          <button
            type="submit"
            name="action"
            value="save"
            class="btn-ojs-secondary"
            id="btn-save-later"
          >
            Save for Later
          </button>
          <button
            type="submit"
            name="action"
            value="continue"
            class="btn-ojs-primary"
            id="btn-continue"
          >
            Continue
          </button>
        </div>
      </div>
    </.form>
    """
  end

  def contributors_step(assigns) do
    ~H"""
    <div class="ojs-details-grid">
      <div class="ojs-details-aside">
        <h2>Contributors</h2>
        <p>
          Add the contributors (authors) of this submission. One contributor must be the primary
          contact.
        </p>
        <p>You can edit contributor details and reorder them from this step.</p>
      </div>

      <div class="ojs-details-form">
        <div class="ojs-contributor-panel">
          <div class="ojs-contributor-panel-header">
            <h3 class="ojs-contributor-panel-title">Contributors</h3>
            <div class="ojs-contributor-panel-actions">
              <%= if @contributor_view == :order do %>
                <button
                  type="button"
                  class="btn-ojs-primary"
                  id="btn-save-order"
                  phx-click="save_order"
                >
                  Save Order
                </button>
                <button
                  type="button"
                  class="btn-ojs-secondary"
                  id="btn-cancel-order"
                  phx-click="cancel_order"
                >
                  Cancel
                </button>
              <% else %>
                <button
                  type="button"
                  class="btn-ojs-link"
                  id="btn-order-contributors"
                  phx-click="toggle_order"
                >
                  Order
                </button>
                <button
                  type="button"
                  class={["btn-ojs-link", @contributor_view == :preview && "is-active"]}
                  id="btn-preview-contributors"
                  phx-click="toggle_preview"
                >
                  Preview
                </button>
                <button
                  type="button"
                  class="btn-ojs-secondary"
                  id="btn-add-contributor"
                  phx-click="add_contributor"
                >
                  Add Contributor
                </button>
              <% end %>
            </div>
          </div>

          <div class="ojs-contributors-list" id="contributors-list">
            <%= if @contributors == [] do %>
              <div class="ojs-empty-state" id="no-contributors">No contributors added yet.</div>
            <% else %>
              <%= for {contributor, index} <- Enum.with_index(@contributors, 1) do %>
                <div class="ojs-contributor-card" id={"contributor-" <> to_string(contributor.id)}>
                  <%= if contributor.editing do %>
                    <div class="ojs-contributor-edit">
                      <.form
                        for={contributor_edit_form(contributor)}
                        id={"contributor-form-" <> to_string(contributor.id)}
                        class="ojs-contributor-edit-form"
                        phx-change="update_contributor"
                        phx-submit="save_contributor"
                      >
                        <input type="hidden" name="contributor[id]" value={contributor.id} />
                        <h4 class="ojs-block-title ojs-field-full">Edit Contributor</h4>
                        <div class="ojs-field">
                          <label for={"contributor-given-name-" <> to_string(contributor.id)}>
                            Given Name <span class="ojs-req">*</span>
                          </label>
                          <input
                            class="ojs-input"
                            id={"contributor-given-name-" <> to_string(contributor.id)}
                            name="contributor[given_name]"
                            value={contributor.given_name}
                            required
                          />
                        </div>
                        <div class="ojs-field">
                          <label for={"contributor-family-name-" <> to_string(contributor.id)}>
                            Family Name
                          </label>
                          <input
                            class="ojs-input"
                            id={"contributor-family-name-" <> to_string(contributor.id)}
                            name="contributor[family_name]"
                            value={contributor.family_name}
                          />
                        </div>
                        <div class="ojs-field ojs-field-full">
                          <label for={"contributor-preferred-name-" <> to_string(contributor.id)}>
                            Preferred Public Name
                          </label>
                          <p class="ojs-field-hint">
                            If you do not wish to use your given and family name in public lists,
                            you may provide a preferred public name here.
                          </p>
                          <input
                            class="ojs-input"
                            id={"contributor-preferred-name-" <> to_string(contributor.id)}
                            name="contributor[preferred_public_name]"
                            value={contributor.preferred_public_name}
                            placeholder="e.g. A. Fauzi"
                          />
                        </div>
                        <div class="ojs-field ojs-field-full">
                          <label for={"contributor-email-" <> to_string(contributor.id)}>
                            Email <span class="ojs-req">*</span>
                          </label>
                          <input
                            type="email"
                            class="ojs-input"
                            id={"contributor-email-" <> to_string(contributor.id)}
                            name="contributor[email]"
                            value={contributor.email}
                            required
                          />
                        </div>
                        <div class="ojs-field">
                          <label for={"contributor-country-" <> to_string(contributor.id)}>
                            Country
                          </label>
                          <input
                            class="ojs-input"
                            id={"contributor-country-" <> to_string(contributor.id)}
                            name="contributor[country]"
                            value={contributor.country}
                            placeholder="Indonesia"
                          />
                        </div>
                        <div class="ojs-field ojs-field-full">
                          <label for={"contributor-affiliation-" <> to_string(contributor.id)}>
                            Affiliation
                          </label>
                          <input
                            class="ojs-input"
                            id={"contributor-affiliation-" <> to_string(contributor.id)}
                            name="contributor[affiliation]"
                            value={contributor.affiliation}
                            placeholder="e.g. Department, University"
                          />
                        </div>
                        <div class="ojs-field ojs-field-full">
                          <label for={"contributor-bio-" <> to_string(contributor.id)}>
                            Bio Statement
                          </label>
                          <textarea
                            class="ojs-textarea"
                            id={"contributor-bio-" <> to_string(contributor.id)}
                            name="contributor[bio_statement]"
                            rows="3"
                            placeholder="Short biography of the contributor"
                          >{contributor.bio_statement}</textarea>
                        </div>
                        <div class="ojs-field">
                          <label for={"contributor-role-" <> to_string(contributor.id)}>
                            Contributor Role
                          </label>
                          <select
                            class="ojs-select"
                            id={"contributor-role-" <> to_string(contributor.id)}
                            name="contributor[role]"
                          >
                            <%= for role <- @roles do %>
                              <option value={role} selected={contributor.role == role}>
                                {role}
                              </option>
                            <% end %>
                          </select>
                        </div>
                        <div class="ojs-field ojs-contributor-edit-options">
                          <label class="ojs-checkbox-label">
                            <input
                              type="checkbox"
                              name="contributor[corresponding]"
                              value="true"
                              checked={contributor.corresponding}
                            /> Primary contact
                          </label>
                          <label class="ojs-checkbox-label">
                            <input
                              type="checkbox"
                              name="contributor[public_list]"
                              value="true"
                              checked={contributor.public_list}
                            /> Include in public list
                          </label>
                        </div>
                        <div class="ojs-contributor-actions">
                          <button type="submit" class="btn-ojs-primary" id="btn-save-edit">
                            Save
                          </button>
                          <button
                            type="button"
                            class="btn-ojs-secondary"
                            id="btn-cancel-edit"
                            phx-click="cancel_edit_contributor"
                            phx-value-id={contributor.id}
                          >
                            Cancel
                          </button>
                        </div>
                      </.form>
                    </div>
                  <% else %>
                    <%= case @contributor_view do %>
                      <% :order -> %>
                        <div class="ojs-contributor-row">
                          <div class="ojs-contributor-identity">
                            <span class="ojs-order-index">{index}</span>
                            <div class="ojs-contributor-name">
                              {contributor_display_name(contributor, index)}
                            </div>
                          </div>
                          <div class="ojs-contributor-order">
                            <button
                              type="button"
                              class="ojs-order-btn"
                              phx-click="move_contributor"
                              phx-value-id={contributor.id}
                              phx-value-dir="up"
                              aria-label="Move up"
                              disabled={index == 1}
                            >
                              ↑
                            </button>
                            <button
                              type="button"
                              class="ojs-order-btn"
                              phx-click="move_contributor"
                              phx-value-id={contributor.id}
                              phx-value-dir="down"
                              aria-label="Move down"
                              disabled={index == length(@contributors)}
                            >
                              ↓
                            </button>
                          </div>
                        </div>
                      <% :preview -> %>
                        <div class="ojs-contributor-preview-row">
                          <div class="ojs-contributor-identity">
                            <span class="ojs-preview-index">{index}</span>
                            <div class="ojs-preview-identity">
                              <div class="ojs-contributor-name">
                                {contributor_display_name(contributor, index)}
                              </div>
                              <div class="ojs-contributor-detail">
                                {contributor.email || "no email"} · {contributor.role}
                                <%= if contributor.corresponding do %>
                                  · Primary Contact
                                <% end %>
                              </div>
                            </div>
                          </div>
                        </div>
                      <% _ -> %>
                        <div class="ojs-contributor-row">
                          <div class="ojs-contributor-identity">
                            <div class="ojs-contributor-name">
                              {contributor_display_name(contributor, index)}
                            </div>
                            <span class="ojs-contributor-role">{contributor.role}</span>
                          </div>
                          <div class="ojs-contributor-actions-row">
                            <%= if contributor.corresponding do %>
                              <span class="ojs-chip">Primary Contact</span>
                            <% else %>
                              <button
                                type="button"
                                class="ojs-primary-contact-btn"
                                phx-click="set_primary_contact"
                                phx-value-id={contributor.id}
                              >
                                Primary Contact
                              </button>
                            <% end %>
                            <button
                              type="button"
                              class="btn-ojs-link"
                              id={"edit-contributor-" <> to_string(contributor.id)}
                              phx-click="start_edit_contributor"
                              phx-value-id={contributor.id}
                            >
                              Edit
                            </button>
                            <button
                              type="button"
                              class="btn-ojs-link ojs-remove-link"
                              id={"delete-contributor-" <> to_string(contributor.id)}
                              phx-click="delete_contributor"
                              phx-value-id={contributor.id}
                            >
                              Remove
                            </button>
                          </div>
                        </div>
                    <% end %>
                  <% end %>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>

    <div class="ojs-details-footer">
      <.link patch={wizard_path(@submission.id, prev_step(@step))} class="btn-ojs-link" id="btn-back">
        Back
      </.link>

      <div class="ojs-details-actions">
        <span class="ojs-last-saved">{@last_saved}</span>
        <button
          type="button"
          class="btn-ojs-secondary"
          id="btn-save-later"
          phx-click="save_contributors"
          phx-value-action="save"
        >
          Save for Later
        </button>
        <button
          type="button"
          class="btn-ojs-primary"
          id="btn-continue"
          phx-click="save_contributors"
          phx-value-action="continue"
        >
          Continue
        </button>
      </div>
    </div>
    """
  end

  def editors_step(assigns) do
    ~H"""
    <.form for={@form} id="editors-form" phx-submit="save_editors">
      <div class="ojs-details-grid">
        <div class="ojs-details-aside">
          <h2>For the Editor</h2>
          <p>
            Add any comments for the editor, such as related submissions or previous publications.
          </p>
        </div>

        <div class="ojs-details-form">
          <div class="ojs-field-block">
            <label for="editor_comments" class="ojs-field-label">Comments for the Editor</label>
            <p class="ojs-field-desc">
              The editor will see these comments alongside your submission.
            </p>
            <textarea
              id="editor_comments"
              name="submission[editor_comments]"
              class="ojs-textarea ojs-textarea-lg"
              rows="8"
              placeholder="Optional comments for the editor..."
            >{@editor_comments}</textarea>
          </div>
        </div>
      </div>

      <div class="ojs-details-footer">
        <.link
          patch={wizard_path(@submission.id, prev_step(@step))}
          class="btn-ojs-link"
          id="btn-back"
        >
          Back
        </.link>

        <div class="ojs-details-actions">
          <span class="ojs-last-saved">{@last_saved}</span>
          <button
            type="submit"
            name="action"
            value="save"
            class="btn-ojs-secondary"
            id="btn-save-later"
          >
            Save for Later
          </button>
          <button
            type="submit"
            name="action"
            value="continue"
            class="btn-ojs-primary"
            id="btn-continue"
          >
            Continue
          </button>
        </div>
      </div>
    </.form>
    """
  end

  def review_step(assigns) do
    ~H"""
    <.form for={@form} id="review-form" phx-submit="save_review">
      <div class="ojs-details-grid">
        <div class="ojs-details-aside">
          <h2>Review</h2>
          <p>Review the details of your submission before submitting it to the journal.</p>
        </div>

        <div class="ojs-details-form">
          <div class="ojs-review-overview">
            <div class="ojs-review-metric">
              <span class="ojs-review-metric-label">Submission ID</span>
              <span class="ojs-review-metric-value">{@submission.id}</span>
            </div>
            <div class="ojs-review-metric">
              <span class="ojs-review-metric-label">Title</span>
              <span class="ojs-review-metric-value">{display_title(@form)}</span>
            </div>
            <div class="ojs-review-metric">
              <span class="ojs-review-metric-label">Files</span>
              <span class="ojs-review-metric-value">{length(@saved_files)}</span>
            </div>
            <div class="ojs-review-metric">
              <span class="ojs-review-metric-label">Contributors</span>
              <span class="ojs-review-metric-value">{length(@contributors)}</span>
            </div>
          </div>

          <div class="ojs-form-block">
            <h3 class="ojs-block-title">Submission Checklist</h3>
            <ul class="ojs-check-list">
              <li class={[title_provided?(@form) && "checked"]}>
                <span class="ojs-check-icon">✓</span> The title of the submission has been provided.
              </li>
              <li class={[has_abstract?(@form) && "checked"]}>
                <span class="ojs-check-icon">✓</span> The abstract has been written.
              </li>
              <li class={[@saved_files != [] && "checked"]}>
                <span class="ojs-check-icon">✓</span> At least one manuscript file has been uploaded.
              </li>
              <li class={[@contributors != [] && "checked"]}>
                <span class="ojs-check-icon">✓</span>
                Contributors have been added and the primary contact is set.
              </li>
            </ul>
          </div>

          <div class="ojs-notice-box ojs-notice-warning">
            <strong>Submission preparation</strong>
            <p>
              By submitting, you confirm that this work is original, has not been published
              elsewhere, and is not under consideration by another journal.
            </p>
          </div>
        </div>
      </div>

      <div class="ojs-details-footer">
        <.link
          patch={wizard_path(@submission.id, prev_step(@step))}
          class="btn-ojs-link"
          id="btn-back"
        >
          Back
        </.link>

        <div class="ojs-details-actions">
          <span class="ojs-last-saved">{@last_saved}</span>
          <button
            type="submit"
            name="action"
            value="save"
            class="btn-ojs-secondary"
            id="btn-save-later"
          >
            Save for Later
          </button>
          <button
            type="button"
            class="btn-ojs-primary btn-submit-journal"
            id="btn-submit-journal"
            phx-click="submit_submission"
          >
            Submit Submission
          </button>
        </div>
      </div>
    </.form>
    """
  end

  # --- Component helpers ------------------------------------------------

  def contributor_edit_form(contributor) do
    to_form(
      %{
        "id" => contributor.id,
        "given_name" => contributor.given_name,
        "family_name" => contributor.family_name,
        "preferred_public_name" => contributor.preferred_public_name,
        "email" => contributor.email,
        "country" => contributor.country,
        "bio_statement" => contributor.bio_statement,
        "affiliation" => contributor.affiliation,
        "orcid" => contributor.orcid,
        "role" => contributor.role,
        "corresponding" => contributor.corresponding,
        "public_list" => contributor.public_list
      },
      as: :contributor
    )
  end

  def display_title(form) do
    case form[:title].value do
      value when value in [nil, ""] -> "(Untitled submission)"
      value -> value
    end
  end

  def title_provided?(form) do
    value = form[:title].value
    is_binary(value) and String.trim(value) != ""
  end

  def has_abstract?(form) do
    value = form[:abstract].value
    is_binary(value) and strip_html(value) != ""
  end

  def error_to_string(:too_large), do: "File is too large (max 50 MB)."
  def error_to_string(:too_many_files), do: "You can upload at most 10 files."
  def error_to_string(:not_accepted), do: "File type not accepted. Use PDF, DOC, or DOCX."
  def error_to_string(:external_client_error), do: "The upload failed. Please try again."
  def error_to_string(_), do: "Upload error. Please try again."
end
