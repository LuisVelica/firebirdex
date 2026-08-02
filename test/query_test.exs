defmodule Firebirdex.QueryTest do
  use ExUnit.Case, async: true

  alias Firebirdex.{Query, Result}

  test "invalid dates and timestamps decode as nil" do
    query = %Query{charset: :utf_8}

    result = %Result{
      desc: [
        {"INVALID_DATE", :date, 0, 4, false},
        {"INVALID_TIMESTAMP", :timestamp, 0, 8, false}
      ],
      columns: ["INVALID_DATE", "INVALID_TIMESTAMP"],
      num_rows: 1,
      rows: [
        [
          {"INVALID_DATE", {2024, 2, 31}},
          {"INVALID_TIMESTAMP", {{2024, 2, 31}, {12, 0, 0, 0}}}
        ]
      ]
    }

    decoded = DBConnection.Query.decode(query, result, [])

    assert decoded.rows == [[nil, nil]]
  end

  test "valid dates and timestamps still decode normally" do
    query = %Query{charset: :utf_8}

    result = %Result{
      desc: [
        {"VALID_DATE", :date, 0, 4, false},
        {"VALID_TIMESTAMP", :timestamp, 0, 8, false}
      ],
      columns: ["VALID_DATE", "VALID_TIMESTAMP"],
      num_rows: 1,
      rows: [
        [
          {"VALID_DATE", {2024, 2, 29}},
          {"VALID_TIMESTAMP", {{2024, 2, 29}, {12, 34, 56, 123_000}}}
        ]
      ]
    }

    decoded = DBConnection.Query.decode(query, result, [])

    assert decoded.rows == [[~D[2024-02-29], ~N[2024-02-29 12:34:56.123000]]]
  end
end
