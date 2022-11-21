# Dashboard for this project found here: https://app.flipsidecrypto.com/dashboard/sushi-swap-activity-tracking-wbtc-vs-usdc-kxnzp5

library(tidyverse)
library(shroomDK)
api_key <- "0d8ca272-9119-417e-8bd8-e90f15f41dba"

sushi_usdc_query <- "
-- get details for relevant pool
WITH pools AS (
   SELECT
       pool_name,
       pool_address,
       token0,
       token1
   FROM
       ETHEREUM_CORE.DIM_DEX_LIQUIDITY_POOLS
   WHERE
       pool_address = LOWER('0x397FF1542f962076d0BFE58eA045FfA2d347ACa0')
),
-- get details for tokens in relevant pool
decimals AS (
   SELECT
       address,
       symbol,
       decimals
   FROM
       ETHEREUM_CORE.DIM_CONTRACTS
   WHERE
       address = (
           SELECT
               LOWER(token1)
           FROM
               pools
       )
       OR address = (
           SELECT
               LOWER(token0)
           FROM
               pools
       )
),
-- aggregate pool and token details
pool_token_details AS (
   SELECT
       pool_name,
       pool_address,
       token0,
       token1,
       token0.symbol AS token0symbol,
       token1.symbol AS token1symbol,
       token0.decimals AS token0decimals,
       token1.decimals AS token1decimals
   FROM
       pools
       LEFT JOIN decimals AS token0
       ON token0.address = token0
       LEFT JOIN decimals AS token1
       ON token1.address = token1
),
-- find swaps for relevant pool in last 7 days
swaps AS (
   SELECT
       block_number,
       block_timestamp,
       tx_hash,
       event_index,
       contract_address,
       event_name,
       event_inputs,
       event_inputs :amount0In :: INTEGER AS amount0In,
       event_inputs :amount0Out :: INTEGER AS amount0Out,
       event_inputs :amount1In :: INTEGER AS amount1In,
       event_inputs :amount1Out :: INTEGER AS amount1Out,
       event_inputs :sender :: STRING AS sender,
       event_inputs :to :: STRING AS to_address
   FROM
       ETHEREUM_CORE.FACT_EVENT_LOGS
   WHERE
       block_timestamp BETWEEN '2022-04-01' AND '2022-04-17'
       AND event_name = ('Swap')
       AND contract_address = LOWER('0x397FF1542f962076d0BFE58eA045FfA2d347ACa0')
),
-- aggregate pool, token, and swap details
swaps_contract_details AS (
   SELECT
       block_number,
       block_timestamp,
       tx_hash,
       event_index,
       contract_address,
       amount0In,
       amount0Out,
       amount1In,
       amount1Out,
       sender,
       to_address,
       pool_name,
       pool_address,
       token0,
       token1,
       token0symbol,
       token1symbol,
       token0decimals,
       token1decimals
   FROM
       swaps
       LEFT JOIN pool_token_details
       ON contract_address = pool_address
),
-- transform amounts by respective token decimals
final_details AS (
   SELECT
       pool_name,
       pool_address,
       block_number,
       block_timestamp,
       tx_hash,
       amount0In / pow(
           10,
           token0decimals
       ) AS amount0In_ADJ,
       amount0Out / pow(
           10,
           token0decimals
       ) AS amount0Out_ADJ,
       amount1In / pow(
           10,
           token1decimals
       ) AS amount1In_ADJ,
       amount1Out / pow(
           10,
           token1decimals
       ) AS amount1Out_ADJ,
       token0symbol,
       token1symbol
   FROM
       swaps_contract_details
)
-- we will replace this final query later to aggregate our data
SELECT
   DATE_TRUNC(
       'day',
       block_timestamp
   ) AS DATE,
   COUNT(tx_hash) AS swap_count,
   SUM(amount0In_ADJ) + SUM(amount0Out_ADJ) AS usdc_vol
FROM
   final_details
GROUP BY
   DATE
ORDER BY
   DATE DESC
"

sushi_wbtc_query <- "
  -- get details for relevant pool
WITH pools AS (
   SELECT
       pool_name,
       pool_address,
       token0,
       token1
   FROM
       ETHEREUM_CORE.DIM_DEX_LIQUIDITY_POOLS
   WHERE
       pool_address = LOWER('0xceff51756c56ceffca006cd410b03ffc46dd3a58')
),
-- get details for tokens in relevant pool
decimals AS (
   SELECT
       address,
       symbol,
       decimals
   FROM
       ETHEREUM_CORE.DIM_CONTRACTS
   WHERE
       address = (
           SELECT
               LOWER(token1)
           FROM
               pools
       )
       OR address = (
           SELECT
               LOWER(token0)
           FROM
               pools
       )
),
-- aggregate pool and token details
pool_token_details AS (
   SELECT
       pool_name,
       pool_address,
       token0,
       token1,
       token0.symbol AS token0symbol,
       token1.symbol AS token1symbol,
       token0.decimals AS token0decimals,
       token1.decimals AS token1decimals
   FROM
       pools
       LEFT JOIN decimals AS token0
       ON token0.address = token0
       LEFT JOIN decimals AS token1
       ON token1.address = token1
),
-- find swaps for relevant pool during the first two weeks of april
swaps AS (
   SELECT
       block_number,
       block_timestamp,
       tx_hash,
       event_index,
       contract_address,
       event_name,
       event_inputs,
       event_inputs :amount0In :: INTEGER AS amount0In,
       event_inputs :amount0Out :: INTEGER AS amount0Out,
       event_inputs :amount1In :: INTEGER AS amount1In,
       event_inputs :amount1Out :: INTEGER AS amount1Out,
       event_inputs :sender :: STRING AS sender,
       event_inputs :to :: STRING AS to_address
   FROM
       ETHEREUM_CORE.FACT_EVENT_LOGS
   WHERE
       block_timestamp BETWEEN '2022-04-01' AND '2022-04-17'
       AND event_name = ('Swap')
       AND contract_address = LOWER('0xceff51756c56ceffca006cd410b03ffc46dd3a58')
),
-- aggregate pool, token, and swap details
swaps_contract_details AS (
   SELECT
       block_number,
       block_timestamp,
       tx_hash,
       event_index,
       contract_address,
       amount0In,
       amount0Out,
       amount1In,
       amount1Out,
       sender,
       to_address,
       pool_name,
       pool_address,
       token0,
       token1,
       token0symbol,
       token1symbol,
       token0decimals,
       token1decimals
   FROM
       swaps
       LEFT JOIN pool_token_details
       ON contract_address = pool_address
),
-- transform amounts by respective token decimals
final_details AS (
   SELECT
       pool_name,
       pool_address,
       block_number,
       block_timestamp,
       tx_hash,
       amount0In / pow(
           10,
           token0decimals
       ) AS amount0In_ADJ,
       amount0Out / pow(
           10,
           token0decimals
       ) AS amount0Out_ADJ,
       amount1In / pow(
           10,
           token1decimals
       ) AS amount1In_ADJ,
       amount1Out / pow(
           10,
           token1decimals
       ) AS amount1Out_ADJ,
       token0symbol,
       token1symbol
   FROM
       swaps_contract_details
)
-- we will replace this final query later to aggregate our data
SELECT
   DATE_TRUNC(
       'day',
       block_timestamp
   ) AS DATE,
   COUNT(tx_hash) AS swap_count,
   SUM(amount0In_ADJ) + SUM(amount0Out_ADJ) AS WBTC_vol
FROM
   final_details
GROUP BY
   DATE
ORDER BY
   DATE DESC
"

usdc_results <- shroomDK::auto_paginate_query(sushi_usdc_query, api_key = "0d8ca272-9119-417e-8bd8-e90f15f41dba")
wbtc_results <- shroomDK::auto_paginate_query(sushi_wbtc_query, api_key = "0d8ca272-9119-417e-8bd8-e90f15f41dba")

wbtc_price_query <- " 
SELECT 
date_trunc('day', hour) as day,
avg(price) as btc_price
FROM ethereum.token_prices_hourly
WHERE symbol = 'WBTC'
  AND day BETWEEN '2022-04-01' AND '2022-04-16'
GROUP BY day
ORDER BY day ASC
"
wbtc_prices <- shroomDK::auto_paginate_query(wbtc_price_query, api_key = "0d8ca272-9119-417e-8bd8-e90f15f41dba")
wbtc_results["usd_equiv"] <- wbtc_results["WBTC_VOL"] * wbtc_prices["BTC_PRICE"]

# Takes only the month and day as part of the vec
results["DATE"] <- str_sub(results[["DATE"]], 6, 10)


results <- data.frame(DATE = wbtc_prices$DAY, WBTC_VOL = wbtc_results$usd_equiv, USDC_VOL = usdc_results$USDC_VOL, WBTC_SWAPS = wbtc_results$SWAP_COUNT, USDC_SWAPS = usdc_results$SWAP_COUNT)

library(ggplot2)
library(magrittr) # needs to be run every time you start R and want to use %>%
library(dplyr)    # alternatively, this also loads %>%
library(reshape2) # Need to reshape the DF to fit the plot conventions.

plot_results <- melt(results, id.vars="DATE")


plot_results <- plot_results %>%
  filter(variable != "USDC_SWAPS" & variable != "WBTC_SWAPS")
plot_results %>%
  ggplot(aes(x = DATE, y = value, color = variable)) +
  labs(
    title = "SushiSwap Pools April Volume",
    x = "Date",
    y = "Volume (USD)"
  ) +  
  geom_line() +
  geom_point(aes(size=6)) + 
  stat_smooth() 

plot_results <- melt(results, id.vars="DATE")
plot_results <- plot_results %>%
  filter(variable != "USDC_VOL" & variable != "WBTC_VOL")
plot_results %>%
  ggplot(aes(x = DATE, y = value, color = variable)) +
  labs(
    title = "SushiSwap Pools April Swaps",
    x = "Date",
    y = "# Swaps"
  ) +  
  geom_line() +
  geom_point(aes(size=6)) + 
  stat_smooth() 
