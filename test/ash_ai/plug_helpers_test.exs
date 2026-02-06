# SPDX-FileCopyrightText: 2026 ash_ai contributors <https://github.com/ash-project/ash_ai/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshAi.PlugHelpersTest do
  @moduledoc """
  Tests for AshAi.PlugHelpers — storing and retrieving tools on a Plug conn.
  """
  use ExUnit.Case, async: true
  import Plug.Test

  describe "set_tools and get_tools" do
    test "set_tools/2 stores tools in conn.private.ash_ai" do
      conn = conn(:get, "/") |> AshAi.PlugHelpers.set_tools([:list_artists, :create_artist])

      assert %{ash_ai: %{tools: [:list_artists, :create_artist]}} = conn.private
    end

    test "get_tools/1 retrieves tools set by set_tools/2" do
      conn = conn(:get, "/") |> AshAi.PlugHelpers.set_tools([:list_artists, :create_artist])

      assert AshAi.PlugHelpers.get_tools(conn) == [:list_artists, :create_artist]
    end
  end

  describe "edge cases" do
    test "get_tools/1 returns nil on a bare conn" do
      conn = conn(:get, "/")

      assert AshAi.PlugHelpers.get_tools(conn) == nil
    end

    test "get_tools/1 returns nil when conn.private has other keys but no :ash_ai" do
      conn =
        conn(:get, "/")
        |> Plug.Conn.put_private(:some_other_key, %{data: true})

      assert AshAi.PlugHelpers.get_tools(conn) == nil
    end

    test "get_tools/1 returns nil when conn.private.ash_ai exists but has no :tools key" do
      conn =
        conn(:get, "/")
        |> Plug.Conn.put_private(:ash_ai, %{something_else: "value"})

      assert AshAi.PlugHelpers.get_tools(conn) == nil
    end

    test "set_tools/2 with empty list stores [] (not nil)" do
      conn = conn(:get, "/") |> AshAi.PlugHelpers.set_tools([])

      assert AshAi.PlugHelpers.get_tools(conn) == []
    end

    test "set_tools/2 called twice — last write wins" do
      conn =
        conn(:get, "/")
        |> AshAi.PlugHelpers.set_tools([:list_artists])
        |> AshAi.PlugHelpers.set_tools([:create_artist, :update_artist])

      assert AshAi.PlugHelpers.get_tools(conn) == [:create_artist, :update_artist]
    end

    test "set_tools/2 preserves other data in conn.private.ash_ai" do
      conn =
        conn(:get, "/")
        |> Plug.Conn.put_private(:ash_ai, %{other_key: "preserved"})
        |> AshAi.PlugHelpers.set_tools([:list_artists])

      assert AshAi.PlugHelpers.get_tools(conn) == [:list_artists]
      assert conn.private.ash_ai[:other_key] == "preserved"
    end

    test "set_tools/2 with non-atom values in the list stores them as-is" do
      tools = ["string_tool", 42, {:tuple_tool, :read}]
      conn = conn(:get, "/") |> AshAi.PlugHelpers.set_tools(tools)

      assert AshAi.PlugHelpers.get_tools(conn) == tools
    end

    test "set_tools/2 with nil as the tools value stores nil" do
      conn =
        conn(:get, "/")
        |> AshAi.PlugHelpers.set_tools([:list_artists])
        |> AshAi.PlugHelpers.set_tools(nil)

      assert AshAi.PlugHelpers.get_tools(conn) == nil
    end
  end

  describe "coexistence with Ash.PlugHelpers" do
    test "set_tools/2 does not affect Ash.PlugHelpers.get_actor/1" do
      actor = %{id: "user_123"}

      conn =
        conn(:get, "/")
        |> Ash.PlugHelpers.set_actor(actor)
        |> AshAi.PlugHelpers.set_tools([:list_artists])

      assert Ash.PlugHelpers.get_actor(conn) == actor
    end

    test "Ash.PlugHelpers.set_actor/2 does not affect get_tools/1" do
      conn =
        conn(:get, "/")
        |> AshAi.PlugHelpers.set_tools([:list_artists])
        |> Ash.PlugHelpers.set_actor(%{id: "user_123"})

      assert AshAi.PlugHelpers.get_tools(conn) == [:list_artists]
    end

    test "set_tools after set_actor and set_tenant — all three coexist" do
      actor = %{id: "user_123"}
      tenant = "tenant_org"
      tools = [:list_artists, :create_artist]

      conn =
        conn(:get, "/")
        |> Ash.PlugHelpers.set_actor(actor)
        |> Ash.PlugHelpers.set_tenant(tenant)
        |> AshAi.PlugHelpers.set_tools(tools)

      assert Ash.PlugHelpers.get_actor(conn) == actor
      assert Ash.PlugHelpers.get_tenant(conn) == tenant
      assert AshAi.PlugHelpers.get_tools(conn) == tools
    end
  end

  describe "boundary" do
    test "get_tools/1 with a non-conn value returns nil" do
      assert AshAi.PlugHelpers.get_tools(%{not_a: "conn"}) == nil
    end
  end
end
