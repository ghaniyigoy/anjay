defmodule OjsLanding.UserTest do
  use ExUnit.Case, async: true

  alias OjsLanding.User

  describe "find_by_username/1" do
    test "returns the admin user with OJS role mapped to :admin" do
      user = User.find_by_username("adminhana")

      assert user.username == "adminhana"
      assert user.email == "ha.sooofi@gmail.com"
      assert :admin in user.roles
      assert User.has_role?(user, :admin)
      assert User.primary_role(user) == :admin
    end

    test "returns nil for an unknown username" do
      assert is_nil(User.find_by_username("does_not_exist"))
    end
  end

  describe "verify_login/2" do
    test "rejects an unknown user" do
      assert {:error, _} = User.verify_login("does_not_exist", "whatever")
    end

    test "rejects a wrong password" do
      assert {:error, "Password salah"} = User.verify_login("adminhana", "wrong-password")
    end
  end
end
