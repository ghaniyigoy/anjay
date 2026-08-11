defmodule OjsLandingWeb.PageControllerTest do
  use OjsLandingWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "Informatika"
    assert response =~ "Jurnal Perang Dunia 1"
    assert response =~ "Lihat Jurnal Terbitan Terkini"
  end
end
