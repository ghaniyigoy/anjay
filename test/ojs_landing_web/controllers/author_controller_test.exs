defmodule OjsLandingWeb.AuthorControllerTest do
  use OjsLandingWeb.ConnCase

  alias OjsLanding.Submission

  describe "authentication" do
    test "GET /submission/wizard/:id redirects to login when not authenticated" do
      conn = get(build_conn(), "/submission/wizard/14?tab=details")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "login"
    end
  end

  describe "submission wizard" do
    setup %{conn: conn} do
      {:ok, conn: init_test_session(conn, current_user: "author1")}
    end

    test "GET /submission/wizard/14?tab=details renders the details tab", %{conn: conn} do
      conn = get(conn, "/submission/wizard/14?tab=details")
      html = html_response(conn, 200)

      assert html =~ "Submission 14"
      assert html =~ "submission-details-form"
      assert html =~ "Deteksi Berita Palsu"
      assert html =~ "step-files"
      assert html =~ "Make a Submission: Details"
      assert html =~ "Please provide the following details to help us manage your submission"
    end

    test "GET /submission/wizard/14 renders every workflow tab", %{conn: conn} do
      for {tab, needle} <- [
            {"details", "submission-details-form"},
            {"files", "submission-dropzone"},
            {"contributors", "btn-add-contributor"},
            {"editors", "editor-comments-editor"},
            {"review", "btn-submit-journal"}
          ] do
        conn = get(conn, "/submission/wizard/14?tab=#{tab}")

        assert html_response(conn, 200) =~ needle,
               "expected tab #{tab} to render #{needle}"
      end
    end

    test "contributors tab in order view shows Save Order and Cancel", %{conn: conn} do
      conn = get(conn, "/submission/wizard/14?tab=contributors&view=order")
      html = html_response(conn, 200)

      assert html =~ "btn-save-order"
      assert html =~ "btn-cancel-order"
      assert html =~ "Save Order"
      assert html =~ "Cancel"
      refute html =~ ~s(id="btn-add-contributor")
    end

    test "edit view renders the contributor edit form", %{conn: conn} do
      conn = get(conn, "/submission/wizard/14?tab=contributors&view=edit&contributor_id=1")
      html = html_response(conn, 200)

      assert html =~ "contributor-edit-form"
      assert html =~ "Edit Contributor"
      assert html =~ "edit-given-name"
      assert html =~ "edit-family-name"
      assert html =~ "edit-preferred-name"
      assert html =~ "edit-bio"
      assert html =~ "edit-public-list"
      assert html =~ "Ahmad"
    end

    test "updates a contributor via the edit form", %{conn: conn} do
      submission = Submission.create("author1")

      {:ok, _} =
        Submission.update(submission.id, %{
          "contributors" => [
            %{id: 1, given_name: "Ahmad", family_name: "Fauzi", role: :author, primary: true}
          ]
        })

      conn =
        put(conn, "/submission/wizard/#{submission.id}?tab=contributors", %{
          "submission" => %{
            "contributor_edit_id" => "1",
            "contributor_edit" => %{
              "given_name" => "Budi",
              "family_name" => "Santoso",
              "preferred_public_name" => "B. Santoso",
              "email" => "budi@test.com",
              "country" => "Malaysia",
              "bio_statement" => "Peneliti sistem informasi.",
              "affiliation" => "Universitas Teknologi",
              "role" => "author",
              "primary" => "false",
              "public_list" => "false"
            }
          }
        })

      assert redirected_to(conn) == "/submission/wizard/#{submission.id}?tab=contributors"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "berhasil diperbarui"

      [contributor] = Submission.get(submission.id).contributors
      assert contributor.given_name == "Budi"
      assert contributor.family_name == "Santoso"
      assert contributor.preferred_public_name == "B. Santoso"
      assert contributor.email == "budi@test.com"
      assert contributor.country == "Malaysia"
      assert contributor.bio_statement == "Peneliti sistem informasi."
      assert contributor.affiliation == "Universitas Teknologi"
      assert contributor.public_list == false
    end

    test "edit view renders the form for the default author of a fresh submission", %{conn: conn} do
      submission = Submission.create("author1")

      conn =
        get(
          conn,
          "/submission/wizard/#{submission.id}?tab=contributors&view=edit&contributor_id=2"
        )

      html = html_response(conn, 200)

      assert html =~ "contributor-edit-form"
      assert html =~ "Edit Contributor"
      assert html =~ "edit-given-name"
      assert html =~ "Ahmad"
      assert html =~ "edit-public-list"
    end

    test "updates and persists the default author of a fresh submission", %{conn: conn} do
      submission = Submission.create("author1")

      conn =
        put(conn, "/submission/wizard/#{submission.id}?tab=contributors", %{
          "submission" => %{
            "contributor_edit_id" => "2",
            "contributor_edit" => %{
              "given_name" => "Ahmad",
              "family_name" => "Fauzi",
              "email" => "ahmad@informatika.ac.id",
              "affiliation" => "Universitas Teknologi",
              "country" => "Indonesia",
              "role" => "author",
              "primary" => "true",
              "public_list" => "true"
            }
          }
        })

      assert redirected_to(conn) == "/submission/wizard/#{submission.id}?tab=contributors"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "berhasil diperbarui"

      assert [contributor] = Submission.get(submission.id).contributors
      assert contributor.id == 2
      assert contributor.given_name == "Ahmad"
      assert contributor.family_name == "Fauzi"
      assert contributor.email == "ahmad@informatika.ac.id"
      assert contributor.primary == true
    end

    test "deletes a contributor via the delete button", %{conn: conn} do
      submission = Submission.create("author1")

      {:ok, _} =
        Submission.update(submission.id, %{
          "contributors" => [
            %{id: 1, given_name: "Ahmad", family_name: "Fauzi", role: :author, primary: true},
            %{id: 2, given_name: "Dewi", family_name: "Lestari", role: :author, primary: false}
          ]
        })

      conn =
        put(conn, "/submission/wizard/#{submission.id}?tab=contributors", %{
          "submission" => %{"delete_contributor_id" => "1"}
        })

      assert redirected_to(conn) == "/submission/wizard/#{submission.id}?tab=contributors"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "dihapus"

      assert [contributor] = Submission.get(submission.id).contributors
      assert contributor.id == 2
    end

    test "Add Contributor opens the edit form for a new blank contributor", %{conn: conn} do
      submission = Submission.create("author1")

      conn =
        get(
          conn,
          "/submission/wizard/#{submission.id}?tab=contributors&view=edit&contributor_id=3"
        )

      html = html_response(conn, 200)

      assert html =~ "contributor-edit-form"
      assert html =~ "edit-given-name"
      assert html =~ ~s(id="edit-given-name")
      assert html =~ "Edit Contributor"
      refute html =~ ~s(name="submission[contributor_edit][given_name]" value="Ahmad")
    end

    test "adds and persists a new contributor via the edit form", %{conn: conn} do
      submission = Submission.create("author1")

      conn =
        put(conn, "/submission/wizard/#{submission.id}?tab=contributors", %{
          "submission" => %{
            "contributor_edit_id" => "3",
            "contributor_edit" => %{
              "given_name" => "Cahyo",
              "family_name" => "Prakoso",
              "email" => "cahyo@test.com",
              "affiliation" => "Institut Teknologi",
              "country" => "Indonesia",
              "role" => "author",
              "primary" => "false",
              "public_list" => "true"
            }
          }
        })

      assert redirected_to(conn) == "/submission/wizard/#{submission.id}?tab=contributors"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "berhasil diperbarui"

      contributors = Submission.get(submission.id).contributors
      assert Enum.any?(contributors, &(&1.id == 3))
      cahyo = Enum.find(contributors, &(&1.id == 3))
      assert cahyo.given_name == "Cahyo"
      assert cahyo.family_name == "Prakoso"
      assert cahyo.email == "cahyo@test.com"
      assert cahyo.primary == false
    end

    test "files tab renders Edit/Remove actions and the genre prompt for files without a genre",
         %{conn: conn} do
      submission = Submission.create("author1")

      {:ok, _} =
        Submission.update(submission.id, %{
          "files" => [
            %{id: 1, filename: "draft.docx", genre: "", size: "2 MB", date: "2026-08-19"},
            %{
              id: 2,
              filename: "manuscript.pdf",
              genre: "Manuscript",
              size: "1 MB",
              date: "2026-08-19"
            }
          ]
        })

      conn = get(conn, "/submission/wizard/#{submission.id}?tab=files")
      html = html_response(conn, 200)

      assert html =~ "draft.docx"
      assert html =~ "data-file-edit"
      assert html =~ "data-file-remove"
      assert html =~ "What kind of file is this?"
      assert html =~ "Article Text"
      assert html =~ "Other"
      assert html =~ "ojs-genre-chip"
    end

    test "GET /submission/wizard/:id redirects to my submissions when not found", %{conn: conn} do
      conn = get(conn, "/submission/wizard/9999?tab=details")

      assert redirected_to(conn) == "/dashboard/mySubmissions"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "tidak ditemukan"
    end

    test "PUT /submission/wizard/:id saves the details form", %{conn: conn} do
      submission = Submission.create("author1")

      conn =
        put(
          conn,
          "/submission/wizard/#{submission.id}?tab=details",
          %{
            "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
            "submission" => %{"title" => "Judul Baru", "section" => "Studi Kasus"}
          }
        )

      assert redirected_to(conn) == "/submission/wizard/#{submission.id}?tab=details"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "berhasil disimpan"

      updated = Submission.get(submission.id)
      assert updated.title == "Judul Baru"
      assert updated.section == "Studi Kasus"
    end

    test "PUT /submission/wizard/:id submits to journal", %{conn: conn} do
      submission = Submission.create("author1")

      conn =
        put(
          conn,
          "/submission/wizard/#{submission.id}?tab=review",
          %{
            "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
            "submission" => %{"title" => "Judul Dikirim", "submit_to_journal" => "1"}
          }
        )

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "dikirim ke jurnal"
      assert Submission.get(submission.id).status == :active
    end

    test "PUT /submission/wizard/:id with action=continue saves details and advances to files", %{
      conn: conn
    } do
      submission = Submission.create("author1")

      conn =
        put(
          conn,
          "/submission/wizard/#{submission.id}?tab=details",
          %{
            "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
            "action" => "continue",
            "submission" => %{
              "title" => "Judul Lanjut",
              "abstract" => "Abstrak lanjut.",
              "keywords" => "elixir, phoenix",
              "references" => "1. Author. (2026). Title."
            }
          }
        )

      assert redirected_to(conn) == "/submission/wizard/#{submission.id}?tab=files"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "berhasil disimpan"

      updated = Submission.get(submission.id)
      assert updated.title == "Judul Lanjut"
      assert updated.abstract == "Abstrak lanjut."
      assert updated.keywords == "elixir, phoenix"
      assert updated.references == "1. Author. (2026). Title."
    end

    test "PUT details continue does not seed a default contributor early", %{conn: conn} do
      submission = Submission.create("author1")

      conn =
        put(
          conn,
          "/submission/wizard/#{submission.id}?tab=details",
          %{
            "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
            "action" => "continue",
            "submission" => %{
              "title" => "Judul Lanjut",
              "abstract" => "Abstrak lanjut.",
              "keywords" => ""
            }
          }
        )

      assert redirected_to(conn) == "/submission/wizard/#{submission.id}?tab=files"

      assert Submission.get(submission.id).contributors in [nil, []]

      html = get(conn, "/submission/wizard/#{submission.id}?tab=files") |> html_response(200)
      assert html =~ ~s(id="step-contributors")
      refute html =~ ~s(class="ojs-progress-step is-done" id="step-contributors")
    end

    test "PUT /submission/wizard/:id action=continue from contributors seeds the author and advances",
         %{
           conn: conn
         } do
      submission = Submission.create("author1")

      conn =
        put(
          conn,
          "/submission/wizard/#{submission.id}?tab=contributors",
          %{
            "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
            "action" => "continue",
            "submission" => %{"contributors_count" => "0"}
          }
        )

      assert redirected_to(conn) == "/submission/wizard/#{submission.id}?tab=editors"

      [contributor] = Submission.get(submission.id).contributors
      assert contributor.primary == true
      assert contributor.email == "author1@informatika.ac.id"

      html = get(conn, "/submission/wizard/#{submission.id}?tab=editors") |> html_response(200)
      assert html =~ ~s(class="ojs-progress-step is-done" id="step-contributors")
    end

    test "PUT /submission/wizard/:id with action=continue blocks blank abstract", %{conn: conn} do
      submission = Submission.create("author1")

      conn =
        put(
          conn,
          "/submission/wizard/#{submission.id}?tab=details",
          %{
            "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
            "action" => "continue",
            "submission" => %{"title" => "Judul Tanpa Abstrak", "abstract" => ""}
          }
        )

      assert redirected_to(conn) == "/submission/wizard/#{submission.id}?tab=details"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "abstract"
    end

    test "PUT /submission/wizard/:id persists uploaded files via files_json", %{conn: conn} do
      submission = Submission.create("author1")

      files =
        Jason.encode!([
          %{"filename" => "manuscript.docx", "size" => "2.1 MB", "date" => "", "genre" => ""},
          %{
            "filename" => "figures.zip",
            "size" => "4.8 MB",
            "date" => "2026-08-24",
            "genre" => "Article Text"
          }
        ])

      conn =
        put(
          conn,
          "/submission/wizard/#{submission.id}?tab=files",
          %{
            "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
            "action" => "continue",
            "submission" => %{"files_json" => files}
          }
        )

      assert redirected_to(conn) == "/submission/wizard/#{submission.id}?tab=contributors"

      [first, second] = Submission.get(submission.id).files
      assert first.filename == "manuscript.docx"
      assert first.size == "2.1 MB"
      assert first.genre == ""
      assert second.filename == "figures.zip"
      assert second.genre == "Article Text"
      assert second.date == "2026-08-24"
    end

    test "PUT /submission/wizard/:id persists comments for the editor and advances to review", %{
      conn: conn
    } do
      submission = Submission.create("author1")

      conn =
        put(
          conn,
          "/submission/wizard/#{submission.id}?tab=editors",
          %{
            "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
            "action" => "continue",
            "submission" => %{"editor_comments" => "<p>Mohon diperiksa segera.</p>"}
          }
        )

      assert redirected_to(conn) == "/submission/wizard/#{submission.id}?tab=review"

      assert Submission.get(submission.id).editor_comments ==
               "<p>Mohon diperiksa segera.</p>"
    end

    test "review tab shows saved details, files, and editor comments", %{conn: conn} do
      submission = Submission.create("author1")

      {:ok, _} =
        Submission.update(submission.id, %{
          "title" => "Judul Review",
          "abstract" => "Abstrak Review.",
          "keywords" => "kunci satu, kunci dua",
          "references" => "1. Referensi.",
          "editor_comments" => "Komentar editor.",
          "files" => [
            %{filename: "naskah.pdf", size: "1 MB", date: "2026-08-24", genre: "Manuscript"}
          ]
        })

      conn = get(conn, "/submission/wizard/#{submission.id}?tab=review")
      html = html_response(conn, 200)

      assert html =~ "Judul Review"
      assert html =~ "Abstrak Review."
      assert html =~ "kunci satu"
      assert html =~ "kunci dua"
      assert html =~ "1. Referensi."
      assert html =~ "naskah.pdf"
      assert html =~ "Komentar editor."
    end
  end

  describe "start a new submission" do
    setup %{conn: conn} do
      {:ok, conn: init_test_session(conn, current_user: "author1")}
    end

    test "GET /submission/new renders the Make a Submission page", %{conn: conn} do
      conn = get(conn, "/submission/new")
      html = html_response(conn, 200)

      assert html =~ "Make a Submission"
      assert html =~ "Before you begin"
      assert html =~ "Submission Checklist"
      assert html =~ "Privacy Consent"
      assert html =~ "submission-start-form"
      assert html =~ "begin-submission-btn"
      assert html =~ "submission-title"
      assert html =~ "checklist-consent"
      assert html =~ "privacy-consent"
    end

    test "GET /submission/new redirects to login when not authenticated" do
      conn = get(build_conn(), "/submission/new")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "login"
    end

    test "POST /submission/create creates a submission with the title and redirects to the wizard",
         %{conn: conn} do
      conn =
        post(conn, "/submission/create", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "submission" => %{
            "title" => "Judul dari Halaman Make a Submission",
            "checklist_agreed" => "1",
            "privacy_consent" => "1"
          }
        })

      assert redirected_to(conn) =~ "/submission/wizard/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "telah dibuat"

      [submission | _] = Submission.get_by_author("author1")
      assert submission.title == "Judul dari Halaman Make a Submission"
    end

    test "POST /submission/create re-renders the form when the title is blank", %{conn: conn} do
      conn =
        post(conn, "/submission/create", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "submission" => %{"title" => "  "}
        })

      html = html_response(conn, 200)
      assert html =~ "Make a Submission"
      assert html =~ "Judul wajib diisi"
    end
  end

  describe "make a submission: details (OJS 3.5 wizard)" do
    setup %{conn: conn} do
      {:ok, conn: init_test_session(conn, current_user: "author1")}
    end

    test "GET /submission/:id/details renders the page", %{conn: conn} do
      conn = get(conn, "/submission/14/details")
      html = html_response(conn, 200)

      assert html =~ "Make a Submission: Details"
      assert html =~ "Dashboard"
      assert html =~ "My Submissions"
      assert html =~ "Submission 14"
      assert html =~ "submission-details-form"
      assert html =~ "abstract-editor"
      assert html =~ "abstract-toolbar"
      assert html =~ "ojs-progress-steps"
      assert html =~ "btn-continue"
      assert html =~ "btn-save-later"
      assert html =~ "Last saved 16 minutes ago"
      assert html =~ "Upload Files"
      assert html =~ "For the Editors"
    end

    test "GET /submission/:id/details redirects to login when not authenticated" do
      conn = get(build_conn(), "/submission/14/details")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "login"
    end

    test "GET /submission/:id/details redirects to my submissions when not found", %{conn: conn} do
      conn = get(conn, "/submission/9999/details")

      assert redirected_to(conn) == "/dashboard/mySubmissions"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "tidak ditemukan"
    end

    test "POST /submission/:id/details saves and continues to upload files", %{conn: conn} do
      submission = Submission.create("author1")

      conn =
        post(conn, "/submission/#{submission.id}/details", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "action" => "continue",
          "submission" => %{
            "title" => "Judul Detail Baru",
            "abstract" => "Abstrak dari halaman details.",
            "keywords" => "elixir, phoenix",
            "references" => "1. Author. (2026). Title."
          }
        })

      assert redirected_to(conn) == "/submission/wizard/#{submission.id}?tab=files"

      updated = Submission.get(submission.id)
      assert updated.title == "Judul Detail Baru"
      assert updated.abstract == "Abstrak dari halaman details."
      assert updated.keywords == "elixir, phoenix"
      assert updated.references == "1. Author. (2026). Title."
    end

    test "POST /submission/:id/details saves for later and shows saved confirmation", %{
      conn: conn
    } do
      submission = Submission.create("author1")

      conn =
        post(conn, "/submission/#{submission.id}/details", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "action" => "save",
          "submission" => %{"title" => "Judul Simpan Nanti", "abstract" => "Abstrak singkat."}
        })

      assert redirected_to(conn) == "/submission/wizard/#{submission.id}/saved"

      assert Submission.get(submission.id).title == "Judul Simpan Nanti"
    end

    test "GET /submission/wizard/:id/saved renders the saved confirmation page", %{conn: conn} do
      submission = Submission.create("author1", "Judul Simpan Nanti")

      conn = get(conn, "/submission/wizard/#{submission.id}/saved")

      assert html_response(conn, 200) =~ "Saved for Later"
      assert html_response(conn, 200) =~ "submission details have been saved"
      assert html_response(conn, 200) =~ "/submission/wizard/#{submission.id}?tab=files"
    end

    test "POST /submission/:id/details re-renders with errors when required fields are blank",
         %{conn: conn} do
      submission = Submission.create("author1")

      conn =
        post(conn, "/submission/#{submission.id}/details", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "action" => "continue",
          "submission" => %{"title" => "  ", "abstract" => ""}
        })

      html = html_response(conn, 200)
      assert html =~ "A title is required."
      assert html =~ "An abstract is required."
      assert html =~ "Make a Submission: Details"
    end
  end

  describe "author workflow discussions" do
    setup %{conn: conn} do
      {:ok, conn: init_test_session(conn, current_user: "author1")}
    end

    test "workflow page keeps Add Discussion active and marks the modal self-only", %{
      conn: conn
    } do
      submission = Submission.create("author1", "Naskah Diskusi")

      conn = get(conn, "/submission/#{submission.id}/workflow?workflowMenuKey=workflow_1")

      html = html_response(conn, 200)
      assert html =~ "btn-add-discussion-pre"
      assert html =~ ~s|onclick="openPreDiscussionModal()"|
      assert html =~ "data-self-only=\"true\""
      assert html =~ "prd-self-only-error"
    end

    test "clears the self-only flag once an editor is assigned", %{conn: conn} do
      submission = Submission.create("author1", "Naskah Diskusi")
      Submission.assign_editor(submission.id, %{"name" => "Pengelola", "role" => "Editor"})

      conn = get(conn, "/submission/#{submission.id}/workflow?workflowMenuKey=workflow_1")

      html = html_response(conn, 200)
      assert html =~ ~s|onclick="openPreDiscussionModal()"|
      assert html =~ "data-self-only=\"false\""
    end

    test "POST discussion without any other participant is rejected with an error", %{
      conn: conn
    } do
      submission = Submission.create("author1", "Naskah Diskusi")

      conn =
        post(conn, "/submission/#{submission.id}/discussion", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "subject" => "Siapa editor saya?",
          "message" => "Halo"
        })

      assert redirected_to(conn) ==
               "/submission/#{submission.id}/workflow?workflowMenuKey=workflow_1"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Belum ada editor"
      assert Submission.get(submission.id).discussions == []
    end

    test "POST discussion succeeds when an editor is assigned", %{conn: conn} do
      submission = Submission.create("author1", "Naskah Diskusi")
      Submission.assign_editor(submission.id, %{"name" => "Pengelola", "role" => "Editor"})

      conn =
        post(conn, "/submission/#{submission.id}/discussion", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "subject" => "Halo editor",
          "message" => "Mohon cek submitan saya."
        })

      assert redirected_to(conn) ==
               "/submission/#{submission.id}/workflow?workflowMenuKey=workflow_1"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Discussion added"
      assert [%{subject: "Halo editor"}] = Submission.get(submission.id).discussions
    end
  end
end
