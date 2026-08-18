defmodule OjsLanding.OJS.UserUserGroup do
  @moduledoc """
  Ecto schema mapping to the existing OJS `user_user_groups` table (read-only by contract).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:user_user_group_id, :integer, autogenerate: false}
  schema "user_user_groups" do
    field(:user_group_id, :integer)
    field(:user_id, :integer)
    field(:date_start, :naive_datetime)
    field(:date_end, :naive_datetime)
    field(:masthead, :integer)
  end

  def changeset(user_user_group, attrs) do
    user_user_group
    |> cast(attrs, [
      :user_user_group_id,
      :user_group_id,
      :user_id,
      :date_start,
      :date_end,
      :masthead
    ])
    |> validate_required([:user_user_group_id, :user_group_id, :user_id])
  end
end
