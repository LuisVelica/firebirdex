defmodule Firebirdex.TransactionTest do
  use ExUnit.Case, async: false

  test "rollback, consecutive transactions, and standalone writes remain durable" do
    opts = TestHelpers.opts()
    {:ok, conn} = Firebirdex.start_link(opts)

    Firebirdex.query!(conn, "CREATE TABLE transaction_test (id INTEGER PRIMARY KEY)")

    assert {:error, :expected_rollback} =
             Firebirdex.transaction(conn, fn transaction_conn ->
               Firebirdex.query!(transaction_conn, "INSERT INTO transaction_test (id) VALUES (1)")
               Firebirdex.rollback(transaction_conn, :expected_rollback)
             end)

    assert Firebirdex.query!(conn, "SELECT id FROM transaction_test ORDER BY id").rows == []

    assert {:ok, :committed} =
             Firebirdex.transaction(conn, fn transaction_conn ->
               Firebirdex.query!(transaction_conn, "INSERT INTO transaction_test (id) VALUES (2)")
               :committed
             end)

    Firebirdex.query!(conn, "INSERT INTO transaction_test (id) VALUES (3)")
    GenServer.stop(conn)

    {:ok, conn} = Firebirdex.start_link(Keyword.put(opts, :createdb, false))

    assert Firebirdex.query!(conn, "SELECT id FROM transaction_test ORDER BY id").rows == [
             [2],
             [3]
           ]

    assert {:error, :second_rollback} =
             Firebirdex.transaction(conn, fn transaction_conn ->
               Firebirdex.query!(transaction_conn, "INSERT INTO transaction_test (id) VALUES (4)")
               Firebirdex.rollback(transaction_conn, :second_rollback)
             end)

    assert {:ok, :second_commit} =
             Firebirdex.transaction(conn, fn transaction_conn ->
               Firebirdex.query!(transaction_conn, "INSERT INTO transaction_test (id) VALUES (5)")
               :second_commit
             end)

    assert Firebirdex.query!(conn, "SELECT id FROM transaction_test ORDER BY id").rows == [
             [2],
             [3],
             [5]
           ]

    GenServer.stop(conn)
  end
end
