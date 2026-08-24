defmodule OjsLandingWeb.SubmissionWizardLiveTest do
  use OjsLandingWeb.ConnCase

  import Phoenix.LiveViewTest

  alias OjsLanding.Submission

  describe "authentication" do
    test "redirects to login when not authenticated" do
      {:error, {:redirect, %{to: "/login"}}} = live(build_conn(), "/submission/14/wizard/details")
    end

    test "redirects to my submissions when the submission does not exist" do
      conn = init_test_session(build_conn(), current_user: "author1")

      {:error, {:redirect, %{to: "/dashboard/mySubmissions"}}} =
        live(conn, "/submission/9999/wizard/details")
    end
  end

  describe "wizard steps" do
    setup %{conn: conn} do
      {:ok, conn: init_test_session(conn, current_user: "author1")}
    end

    test "renders the details step with the progress steps", %{conn: conn} do
      {:ok, view, html} = live(conn, "/submission/14/wizard/details")

      assert html =~ "Make a Submission: Details"
      assert has_element?(view, "#details-form")
      assert has_element?(view, "#wizard-steps")
      assert has_element?(view, "#step-details")
      assert has_element?(view, "#step-files")
      assert has_element?(view, "#step-contributors")
      assert has_element?(view, "#step-editors")
      assert has_element?(view, "#step-review")
    end

    test "renders every step", %{conn: conn} do
      for {step, selector} <- [
            {"details", "#details-form"},
            {"files", "#files-form"},
            {"contributors", "#btn-add-contributor"},
            {"editors", "#editors-form"},
            {"review", "#btn-submit-journal"}
          ] do
        {:ok, view, _html} = live(conn, "/submission/14/wizard/#{step}")

        assert has_element?(view, selector), "expected step #{step} to render #{selector}"
      end
    end

    test "marks the current step and previous steps as done", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/submission/14/wizard/files")

      assert has_element?(view, "#step-files.is-current")
      assert has_element?(view, "#step-details.is-done")
    end

    test "renders the uploaded files section on the files step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/submission/14/wizard/files")

      assert has_element?(view, "#file-dropzone")
      assert has_element?(view, "#saved-files")
      assert has_element?(view, "#file-row-1")
      assert has_element?(view, "#file-row-2")
    end

    test "shows Edit and Remove actions next to each uploaded file name", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/submission/14/wizard/files")

      assert has_element?(view, "#edit-file-1")
      assert has_element?(view, "#remove-file-1")
      assert has_element?(view, "#edit-file-2")
      assert has_element?(view, "#remove-file-2")
    end

    test "removing a file removes it from the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/submission/14/wizard/files")

      view |> element("#remove-file-1") |> render_click()

      refute has_element?(view, "#file-row-1")
      assert has_element?(view, "#file-row-2")
    end

    test "renders the review step with summary metrics", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/submission/14/wizard/review")

      assert has_element?(view, "#review-form")
      assert render(view) =~ "Submission ID"
      assert render(view) =~ "Submission Checklist"
    end
  end

  describe "details step" do
    setup %{conn: conn} do
      {:ok, conn: init_test_session(conn, current_user: "author1")}
    end

    test "shows validation errors when required fields are blank", %{conn: conn} do
      submission = Submission.create("author1")
      {:ok, view, _html} = live(conn, "/submission/#{submission.id}/wizard/details")

      view
      |> form("#details-form", submission: %{title: "  ", abstract: ""})
      |> render_submit()

      assert has_element?(view, "#details-alert")
      assert view |> element("#title-field") |> render() =~ "A title is required."
      assert view |> element("#abstract-field") |> render() =~ "An abstract is required."
    end

    test "saves the details and continues to the files step", %{conn: conn} do
      submission = Submission.create("author1")
      {:ok, view, _html} = live(conn, "/submission/#{submission.id}/wizard/details")

      view
      |> form(
        "#details-form",
        submission: %{
          title: "Judul Baru",
          abstract: "Abstrak dari wizard.",
          keywords: "elixir, phoenix",
          references: "1. Author. (2026). Title."
        }
      )
      |> render_submit()

      assert_patch(view, "/submission/#{submission.id}/wizard/files")

      updated = Submission.get(submission.id)
      assert updated.title == "Judul Baru"
      assert updated.abstract == "Abstrak dari wizard."
      assert updated.keywords == "elixir, phoenix"
      assert updated.references == "1. Author. (2026). Title."
    end

    test "save for later persists and returns to my submissions", %{conn: conn} do
      submission = Submission.create("author1")
      {:ok, view, _html} = live(conn, "/submission/#{submission.id}/wizard/details")

      view
      |> form("#details-form", submission: %{title: "Disimpan Nanti", abstract: "Abstrak."})
      |> put_submitter("button#btn-save-later")
      |> render_submit()

      assert_redirect(view, "/dashboard/mySubmissions?currentViewId=incomplete-submissions")
      assert Submission.get(submission.id).title == "Disimpan Nanti"
    end
  end

  describe "files step" do
    setup %{conn: conn} do
      {:ok, conn: init_test_session(conn, current_user: "author1")}
    end

    test "asks what kind of file a freshly uploaded file is", %{conn: conn} do
      submission = Submission.create("author1")
      {:ok, view, _html} = live(conn, "/submission/#{submission.id}/wizard/files")

      upload = %{name: "manuscript.pdf", content: "pdf", type: "application/pdf"}

      view
      |> file_input("#files-form", :files, [upload])
      |> render_upload("manuscript.pdf")

      view |> element("#files-form") |> render_change()

      assert render(view) =~ "manuscript.pdf"
      assert has_element?(view, "[id^='genre-prompt-']")
      assert render(view) =~ "What kind of file is this?"
      assert render(view) =~ "Article Text"
      assert render(view) =~ "Other"
    end

    test "assigns a genre when Article Text is chosen", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/submission/14/wizard/files")

      view |> element("#edit-file-1") |> render_click()

      assert has_element?(view, "#genre-picker-1")

      view
      |> element("#genre-picker-1 .ojs-genre-option:first-of-type")
      |> render_click()

      assert has_element?(view, "#genre-set-1")
      assert view |> element("#genre-set-1") |> render() =~ "Article Text"
      refute has_element?(view, "#genre-picker-1")
    end

    test "clicking Other opens the full genre list with all options", %{conn: conn} do
      submission = Submission.create("author1")
      {:ok, view, _html} = live(conn, "/submission/#{submission.id}/wizard/files")

      upload = %{name: "supplement.pdf", content: "pdf", type: "application/pdf"}

      view
      |> file_input("#files-form", :files, [upload])
      |> render_upload("supplement.pdf")

      view |> element("#files-form") |> render_change()

      view
      |> element("[id^='genre-prompt-'] .ojs-genre-option:last-of-type")
      |> render_click()

      assert has_element?(view, "[id^='genre-picker-']")
      assert render(view) =~ "What kind of file is this?"
      assert render(view) =~ "Choose the option that best describes this file"
      assert render(view) =~ "Research Instrument"
      assert render(view) =~ "Research Materials"
      assert render(view) =~ "Research Results"
      assert render(view) =~ "Transcripts"
      assert render(view) =~ "Data Analysis"
      assert render(view) =~ "Data Set"
      assert render(view) =~ "Source Texts"
    end

    test "assigns a genre when Other is chosen from the full list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/submission/14/wizard/files")

      view |> element("#edit-file-1") |> render_click()

      assert has_element?(view, "#genre-picker-1")

      view
      |> element("#genre-picker-1 .ojs-genre-option:last-of-type")
      |> render_click()

      assert view |> element("#genre-set-1") |> render() =~ "Other"
    end

    test "edit reopens the genre picker to change the file type", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/submission/14/wizard/files")

      assert has_element?(view, "#genre-set-1")
      refute has_element?(view, "#genre-picker-1")

      view |> element("#edit-file-1") |> render_click()

      refute has_element?(view, "#genre-set-1")
      assert has_element?(view, "#genre-picker-1")
      assert render(view) =~ "Choose the option that best describes this file"
    end

    test "cancelling the genre picker keeps the file type unchanged", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/submission/14/wizard/files")

      view |> element("#edit-file-1") |> render_click()

      assert has_element?(view, "#genre-picker-1")

      view |> element("#cancel-genre-1") |> render_click()

      refute has_element?(view, "#genre-picker-1")
      assert has_element?(view, "#genre-set-1")
      assert view |> element("#genre-set-1") |> render() =~ "Manuscript"
    end
  end

  describe "contributors step" do
    setup %{conn: conn} do
      {:ok, conn: init_test_session(conn, current_user: "author1")}
    end

    test "lists the default author as a contributor", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/submission/14/wizard/contributors")

      assert has_element?(view, "#contributor-1")
      assert render(view) =~ "Ahmad"
    end

    test "adds a new contributor and saves it", %{conn: conn} do
      submission = Submission.create("author1")
      {:ok, view, _html} = live(conn, "/submission/#{submission.id}/wizard/contributors")

      view |> element("#btn-add-contributor") |> render_click()

      assert has_element?(view, "#contributor-form-2")

      view
      |> form("#contributor-form-2",
        contributor: %{
          given_name: "Budi",
          family_name: "Santoso",
          email: "budi@test.com",
          country: "Indonesia",
          role: "Author",
          public_list: "true"
        }
      )
      |> render_submit()

      assert render(view) =~ "Budi"
    end

    test "edits an existing contributor with all OJS fields", %{conn: conn} do
      submission = Submission.create("author1")

      {:ok, _} =
        Submission.update(submission.id, %{
          "contributors" => [
            %{
              id: 1,
              given_name: "Ahmad",
              family_name: "Fauzi",
              email: "a@test.com",
              role: :author,
              primary: true
            }
          ]
        })

      {:ok, view, _html} = live(conn, "/submission/#{submission.id}/wizard/contributors")

      view |> element("#edit-contributor-1") |> render_click()

      assert has_element?(view, "#contributor-form-1")
      assert has_element?(view, "#contributor-given-name-1")
      assert has_element?(view, "#contributor-family-name-1")
      assert has_element?(view, "#contributor-preferred-name-1")
      assert has_element?(view, "#contributor-email-1")
      assert has_element?(view, "#contributor-country-1")
      assert has_element?(view, "#contributor-bio-1")
      assert has_element?(view, "#contributor-affiliation-1")
      assert has_element?(view, "#contributor-role-1")

      view
      |> form("#contributor-form-1",
        contributor: %{
          given_name: "Ahmad",
          family_name: "Fauzi",
          preferred_public_name: "A. Fauzi",
          email: "ahmad2@test.com",
          country: "Malaysia",
          bio_statement: "Peneliti NLP",
          affiliation: "Universitas Teknologi",
          role: "Author"
        }
      )
      |> render_submit()

      assert render(view) =~ "Ahmad Fauzi"

      view |> element("#btn-continue") |> render_click()
      assert_patch(view, "/submission/#{submission.id}/wizard/editors")

      [contributor] = Submission.get(submission.id).contributors
      assert contributor.preferred_public_name == "A. Fauzi"
      assert contributor.email == "ahmad2@test.com"
      assert contributor.country == "Malaysia"
      assert contributor.bio_statement == "Peneliti NLP"
      assert contributor.affiliation == "Universitas Teknologi"
    end

    test "deletes a contributor", %{conn: conn} do
      submission = Submission.create("author1")
      {:ok, view, _html} = live(conn, "/submission/#{submission.id}/wizard/contributors")

      view |> element("#delete-contributor-1") |> render_click()

      refute has_element?(view, "#contributor-1")
    end

    test "order mode shows Save Order and Cancel buttons", %{conn: conn} do
      submission = Submission.create("author1")
      {:ok, view, _html} = live(conn, "/submission/#{submission.id}/wizard/contributors")

      view |> element("#btn-order-contributors") |> render_click()

      assert has_element?(view, "#btn-save-order")
      assert has_element?(view, "#btn-cancel-order")
      refute has_element?(view, "#btn-order-contributors")

      view |> element("#btn-cancel-order") |> render_click()

      refute has_element?(view, "#btn-save-order")
      assert has_element?(view, "#btn-order-contributors")
    end
  end

  describe "review step" do
    setup %{conn: conn} do
      {:ok, conn: init_test_session(conn, current_user: "author1")}
    end

    test "submitting shows the received page and activates the submission", %{conn: conn} do
      submission = Submission.create("author1")
      {:ok, view, _html} = live(conn, "/submission/#{submission.id}/wizard/review")

      view |> element("#btn-submit-journal") |> render_click()

      assert has_element?(view, "#submission-received")
      assert render(view) =~ "Submission Received"
      assert Submission.get(submission.id).status == :active
    end
  end
end
