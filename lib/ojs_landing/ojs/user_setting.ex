defmodule OjsLanding.OJS.UserSetting do
  @moduledoc """
  Ecto schema mapping to the existing OJS `user_settings` table (read-only by contract).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:user_setting_id, :integer, autogenerate: false}
  schema "user_settings" do
    field(:user_id, :integer)
    field(:locale, :string)
    field(:setting_name, :string)
    field(:setting_value, :string)
  end

  def changeset(user_setting, attrs) do
    user_setting
    |> cast(attrs, [:user_setting_id, :user_id, :locale, :setting_name, :setting_value])
    |> validate_required([:user_setting_id, :user_id])
  end
end
