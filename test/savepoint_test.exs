defmodule Firebirdex.SavepointTest do
  use ExUnit.Case, async: false

  alias Firebirdex.Connection

  test "nested savepoints use a stack and survive Firebird 3 implicit rollback" do
    {:ok, state} = Connection.connect(TestHelpers.opts())

    :ok =
      :efirebirdsql_protocol.exec_immediate(
        "CREATE TABLE savepoint_test (id INTEGER PRIMARY KEY)",
        state.conn
      )

    {:ok, _, transaction_state} = Connection.handle_begin([], state)

    :ok =
      :efirebirdsql_protocol.exec_immediate(
        "INSERT INTO savepoint_test (id) VALUES (1)",
        transaction_state.conn
      )

    {:ok, _, first_savepoint} =
      Connection.handle_begin([mode: :savepoint], transaction_state)

    {:ok, _, second_savepoint} =
      Connection.handle_begin([mode: :savepoint], first_savepoint)

    assert second_savepoint.savepoints == [
             "firebirdex_savepoint_2",
             "firebirdex_savepoint_1"
           ]

    {:ok, _, first_savepoint} =
      Connection.handle_rollback([mode: :savepoint], second_savepoint)

    assert first_savepoint.savepoints == ["firebirdex_savepoint_1"]

    assert {:error, _, _} =
             :efirebirdsql_protocol.exec_immediate(
               "INSERT INTO savepoint_test (id) VALUES (1)",
               first_savepoint.conn
             )

    {:ok, _, transaction_state} =
      Connection.handle_rollback([mode: :savepoint], first_savepoint)

    assert transaction_state.savepoints == []

    {:ok, _, idle_state} = Connection.handle_rollback([], transaction_state)
    assert idle_state.transaction_status == :idle
    assert :ok = Connection.disconnect(:normal, idle_state)
  end
end
