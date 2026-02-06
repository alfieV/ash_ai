# SPDX-FileCopyrightText: 2026 ash_ai contributors <https://github.com/ash-project/ash_ai/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshAi.Mcp.PlugToolsTest do
  @moduledoc """
  Tests for MCP server reading tools from conn.private via AshAi.PlugHelpers.
  """
  use AshAi.RepoCase, async: false
  import Plug.{Conn, Test}

  alias AshAi.Mcp.Router
  alias AshAi.Test.Music

  # opts WITHOUT tools — lets conn.private or default take over
  @opts_no_tools [otp_app: :ash_ai]
  # opts WITH tools — router-level config
  @opts_with_tools [tools: [:list_artists], otp_app: :ash_ai]

  describe "conn.private tools filtering" do
    test "tools/list with conn-level tools returns only those tools" do
      session_id = initialize_and_get_session_id(@opts_no_tools)

      response =
        conn(:post, "/", %{"method" => "tools/list", "id" => "list_1"})
        |> put_req_header("mcp-session-id", session_id)
        |> AshAi.PlugHelpers.set_tools([:list_artists])
        |> Router.call(@opts_no_tools)

      body = decode_response(response)

      assert response.status == 200
      tool_names = Enum.map(body["result"]["tools"], & &1["name"])
      assert tool_names == ["list_artists"]
    end

    test "tools/call succeeds for a tool in the conn-level tools list" do
      session_id = initialize_and_get_session_id(@opts_no_tools)

      Music.create_artist_after_action!(%{
        name: "Conn Tools Artist",
        bio: "Testing conn-level tool access"
      })

      response =
        conn(:post, "/", %{
          "method" => "tools/call",
          "id" => "call_1",
          "params" => %{"name" => "list_artists"}
        })
        |> put_req_header("mcp-session-id", session_id)
        |> AshAi.PlugHelpers.set_tools([:list_artists])
        |> Router.call(@opts_no_tools)

      body = decode_response(response)

      assert response.status == 200
      assert body["result"]["isError"] == false
      assert %{"result" => %{"content" => [%{"type" => "text", "text" => text}]}} = body
      assert [%{"name" => "Conn Tools Artist"}] = Jason.decode!(text)
    end
  end

  describe "precedence" do
    test "router opts tools takes precedence over conn.private tools" do
      session_id = initialize_and_get_session_id(@opts_with_tools)

      # Router opts allow :list_artists only. Conn.private sets :create_artist.
      # Router should win — only :list_artists should appear.
      response =
        conn(:post, "/", %{"method" => "tools/list", "id" => "list_1"})
        |> put_req_header("mcp-session-id", session_id)
        |> AshAi.PlugHelpers.set_tools([:create_artist_after])
        |> Router.call(@opts_with_tools)

      body = decode_response(response)

      assert response.status == 200
      tool_names = Enum.map(body["result"]["tools"], & &1["name"])
      assert tool_names == ["list_artists"]
    end

    test "neither router nor conn.private sets tools — all tools returned" do
      session_id = initialize_and_get_session_id(@opts_no_tools)

      response =
        conn(:post, "/", %{"method" => "tools/list", "id" => "list_1"})
        |> put_req_header("mcp-session-id", session_id)
        |> Router.call(@opts_no_tools)

      body = decode_response(response)

      assert response.status == 200
      tool_names = Enum.map(body["result"]["tools"], & &1["name"])
      # The Music domain defines 6 tools
      assert length(tool_names) == 6
    end
  end

  describe "edge cases" do
    test "conn-level tools set to [] — tools/list returns empty list" do
      session_id = initialize_and_get_session_id(@opts_no_tools)

      response =
        conn(:post, "/", %{"method" => "tools/list", "id" => "list_1"})
        |> put_req_header("mcp-session-id", session_id)
        |> AshAi.PlugHelpers.set_tools([])
        |> Router.call(@opts_no_tools)

      body = decode_response(response)

      assert response.status == 200
      assert body["result"]["tools"] == []
    end

    test "tools/call for a tool NOT in conn-level tools returns error" do
      session_id = initialize_and_get_session_id(@opts_no_tools)

      response =
        conn(:post, "/", %{
          "method" => "tools/call",
          "id" => "call_1",
          "params" => %{"name" => "list_artists"}
        })
        |> put_req_header("mcp-session-id", session_id)
        |> AshAi.PlugHelpers.set_tools([:create_artist_after])
        |> Router.call(@opts_no_tools)

      body = decode_response(response)

      assert response.status == 200
      assert body["error"]["code"] == -32_602
      assert body["error"]["message"] == "Tool not found: list_artists"
    end
  end

  # Helper functions

  defp initialize_and_get_session_id(opts) do
    response =
      conn(:post, "/", %{
        "method" => "initialize",
        "id" => "init_1",
        "params" => %{"client" => %{"name" => "test_client", "version" => "1.0.0"}}
      })
      |> Router.call(opts)

    extract_session_id(response)
  end

  defp extract_session_id(response) do
    List.first(Plug.Conn.get_resp_header(response, "mcp-session-id"))
  end

  defp decode_response(response) do
    Jason.decode!(response.resp_body)
  end
end
