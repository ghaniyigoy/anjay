defmodule OjsLandingWeb.EditorControllerTest do
  use OjsLandingWeb.ConnCase

  alias OjsLanding.Submission

  describe "editorial dashboard" do
    setup %{conn: conn} do
      {:ok, conn: init_test_session(conn, current_user: "editor")}
    end

    test "GET /dashboard/editorial renders the editorial dashboard", %{conn: conn} do
      conn = get(conn, "/dashboard/editorial")

      assert html_response(conn, 200) =~ "Editor Dashboard"
    end

    test "shows the contributor name from the submission, not the account name", %{conn: conn} do
      submission = Submission.create("author1", "Naskah Nama Kontributor")

      {:ok, _} =
        Submission.update(submission.id, %{
          "title" => "Naskah Nama Kontributor",
          "contributors" => [
            %{
              id: 1,
              given_name: "Siti",
              family_name: "Marpuah",
              email: "siti@test.com",
              affiliation: "Universitas Contoh",
              country: "Indonesia",
              role: :author,
              primary: true
            }
          ]
        })

      Submission.set_status(submission.id, :active)

      conn = get(conn, "/dashboard/editorial?currentViewId=active")
      html = html_response(conn, 200)

      assert html =~ "Naskah Nama Kontributor"
      assert html =~ "Siti Marpuah"
    end

    test "falls back to the account name when there are no contributors", %{conn: conn} do
      submission = Submission.create("author1", "Naskah Tanpa Kontributor")

      Submission.set_status(submission.id, :active)

      conn = get(conn, "/dashboard/editorial?currentViewId=active")
      html = html_response(conn, 200)

      assert html =~ "Ahmad Fauzi"
    end
  end
end
