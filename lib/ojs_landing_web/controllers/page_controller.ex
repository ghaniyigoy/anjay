defmodule OjsLandingWeb.PageController do
  use OjsLandingWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
