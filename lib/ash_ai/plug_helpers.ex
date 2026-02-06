# SPDX-FileCopyrightText: 2026 ash_ai contributors <https://github.com/ash-project/ash_ai/graphs/contributors>
#
# SPDX-License-Identifier: MIT

if Code.ensure_loaded?(Plug.Conn) do
  defmodule AshAi.PlugHelpers do
    @moduledoc """
    Helpers for storing AshAi-specific data in the Plug connection.

    This module follows the same pattern as `Ash.PlugHelpers`, using
    `conn.private` to pass request-scoped configuration through plug pipelines.

    Values are stored under the `:ash_ai` key in `conn.private`, separate from
    the `:ash` key used by `Ash.PlugHelpers`.

    ## Example

        # In a plug or controller
        conn
        |> AshAi.PlugHelpers.set_tools([:list_artists, :create_artist])

        # Later, in the MCP server
        AshAi.PlugHelpers.get_tools(conn)
        # => [:list_artists, :create_artist]
    """

    alias Plug.Conn

    @doc """
    Sets the list of tool names to expose on this connection.

    The tools are stored in `conn.private.ash_ai.tools`.

    ## Example

        conn = AshAi.PlugHelpers.set_tools(conn, [:list_artists, :create_artist])
    """
    @spec set_tools(Conn.t(), [atom()] | nil) :: Conn.t()
    def set_tools(conn, tools) do
      ash_ai_private =
        conn.private
        |> Map.get(:ash_ai, %{})
        |> Map.put(:tools, tools)

      Conn.put_private(conn, :ash_ai, ash_ai_private)
    end

    @doc """
    Retrieves the list of tool names from the connection.

    Returns `nil` if no tools have been set, which is distinct from `[]`
    (an empty list meaning "no tools allowed").

    ## Example

        AshAi.PlugHelpers.get_tools(conn)
        # => [:list_artists, :create_artist]
    """
    @spec get_tools(Conn.t()) :: [atom()] | nil
    def get_tools(%{private: %{ash_ai: %{tools: tools}}}), do: tools
    def get_tools(_), do: nil
  end
else
  defmodule AshAi.PlugHelpers do
    @moduledoc false

    def set_tools(_conn, _tools) do
      raise ArgumentError, "AshAi.PlugHelpers.set_tools/2 requires `Plug` to be available"
    end

    def get_tools(_conn) do
      raise ArgumentError, "AshAi.PlugHelpers.get_tools/1 requires `Plug` to be available"
    end
  end
end
