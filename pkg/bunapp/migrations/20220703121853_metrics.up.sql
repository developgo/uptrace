CREATE TABLE ?DB.measure_minutes ?ON_CLUSTER (
  project_id UInt32 Codec(DoubleDelta, ?CODEC),
  metric LowCardinality(String) Codec(?CODEC),
  time DateTime Codec(DoubleDelta, ?CODEC),
  attrs_hash UInt64 Codec(Delta, ?CODEC),

  instrument LowCardinality(String) Codec(?CODEC),
  sum SimpleAggregateFunction(sumWithOverflow, Float32) Codec(?CODEC),
  count SimpleAggregateFunction(sum, UInt64) Codec(T64, ?CODEC),
  value SimpleAggregateFunction(anyLast, Float32) Codec(?CODEC),
  histogram AggregateFunction(quantilesBFloat16(0.5, 0.9, 0.99), Float32) Codec(?CODEC),

  keys Array(LowCardinality(String)) Codec(?CODEC),
  values Array(LowCardinality(String)) Codec(?CODEC)
)
ENGINE = ?(REPLICATED)AggregatingMergeTree
PARTITION BY toDate(time)
ORDER BY (project_id, metric, time, attrs_hash)
TTL toDate(time) + INTERVAL ?TTL DELETE
SETTINGS ttl_only_drop_parts = 1

--migration:split

CREATE TABLE ?DB.measure_minutes_buffer AS ?DB.measure_minutes
ENGINE = Buffer(?DB, measure_minutes, 8, 10, 30, 10000, 1000000, 10000000, 100000000)

--migration:split

CREATE TABLE ?DB.measure_hours ?ON_CLUSTER (
  project_id UInt32 Codec(DoubleDelta, ?CODEC),
  metric LowCardinality(String) Codec(?CODEC),
  time DateTime Codec(DoubleDelta, ?CODEC),
  attrs_hash UInt64 Codec(Delta, ?CODEC),

  instrument LowCardinality(String) Codec(?CODEC),
  sum SimpleAggregateFunction(sumWithOverflow, Float32) Codec(?CODEC),
  count SimpleAggregateFunction(sum, UInt64) Codec(T64, ?CODEC),
  value SimpleAggregateFunction(anyLast, Float32) Codec(?CODEC),
  histogram AggregateFunction(quantilesBFloat16(0.5, 0.9, 0.99), Float32) Codec(?CODEC),

  keys Array(LowCardinality(String)) Codec(?CODEC),
  values Array(LowCardinality(String)) Codec(?CODEC)
)
ENGINE = ?(REPLICATED)AggregatingMergeTree
PARTITION BY toDate(time)
ORDER BY (project_id, metric, time, attrs_hash)
TTL toDate(time) + INTERVAL ?TTL DELETE
SETTINGS ttl_only_drop_parts = 1

--migration:split

CREATE MATERIALIZED VIEW ?DB.measure_hours_mv ?ON_CLUSTER
TO ?DB.measure_hours
AS SELECT
  project_id,
  metric,
  toStartOfHour(time) AS time,
  attrs_hash,

  anyLast(instrument) AS instrument,
  sumWithOverflow(sum) AS sum,
  sum(count) AS count,
  anyLast(value) AS value,
  quantilesBFloat16MergeState(0.5, 0.9, 0.99)(histogram) AS histogram,

  anyLast(keys) AS keys,
  anyLast(values) AS values
FROM ?DB.measure_minutes
GROUP BY project_id, metric, toStartOfHour(time), attrs_hash
SETTINGS prefer_column_name_to_alias = 1
