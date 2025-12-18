# Fact-checking FT chart: "Britain's economy is highly London-centric"
# Using OECD regional accounts data

library(tidyverse)
library(httr)

cat("=== Detailed Fact-Check of FT Chart ===\n\n")

# Load cached data
df <- readRDS("oecd_regional_gdp.rds")

countries <- c("GBR", "USA", "DEU", "NLD")

# Get total GDP in millions USD PPP
gdp_total <- df |>
  filter(
    COUNTRY %in% countries,
    MEASURE == "GDP",
    UNIT_MEASURE == "USD_PPP",
    UNIT_MULT == 6
  ) |>
  select(
    country = COUNTRY,
    region = REF_AREA,
    level = TERRITORIAL_LEVEL,
    year = TIME_PERIOD,
    gdp_millions = OBS_VALUE
  ) |>
  group_by(country, region, level, year) |>
  summarise(gdp_millions = mean(gdp_millions), .groups = "drop")

# Get population
pop_data <- df |>
  filter(
    COUNTRY %in% countries,
    MEASURE == "POP"
  ) |>
  select(
    country = COUNTRY,
    region = REF_AREA,
    level = TERRITORIAL_LEVEL,
    year = TIME_PERIOD,
    pop = OBS_VALUE
  )

# Calculate GDP per capita (in thousands USD)
gdp_pc <- gdp_total |>
  inner_join(pop_data, by = c("country", "region", "level", "year")) |>
  mutate(
    gdp_pc = (gdp_millions * 1e6 / pop) / 1000
  )

# Check data availability
cat("=== Data Availability by Level and Year ===\n")
gdp_pc |>
  count(country, level, year) |>
  pivot_wider(names_from = year, values_from = n) |>
  print()

# Use 2019 data (pre-COVID)
year_to_use <- 2019

# Compare TL2 vs TL3
cat("\n=== UK at TL2 level (Large Regions) ===\n")
uk_tl2 <- gdp_pc |>
  filter(country == "GBR", level == "TL2", year == year_to_use) |>
  arrange(desc(gdp_pc))
print(uk_tl2)

cat("\n=== UK at TL3 level (Smaller Regions) ===\n")
uk_tl3 <- gdp_pc |>
  filter(country == "GBR", level == "TL3", year == year_to_use) |>
  arrange(desc(gdp_pc))
print(uk_tl3, n = 30)

# For the FT chart, they likely used TL3 regions
# Let's analyze at TL3 level

cat("\n=== Analysis at TL3 Level ===\n")

data_tl3 <- gdp_pc |>
  filter(level == "TL3", year == year_to_use)

# National averages
national_tl3 <- data_tl3 |>
  group_by(country) |>
  summarise(
    total_gdp = sum(gdp_millions),
    total_pop = sum(pop),
    gdp_pc = (total_gdp * 1e6 / total_pop) / 1000,
    n_regions = n(),
    .groups = "drop"
  )

cat("\nNational averages (TL3):\n")
print(national_tl3)

# For UK, London at TL3 might be split into multiple regions
# Let's see London sub-regions
cat("\n=== London TL3 regions ===\n")
london_tl3 <- gdp_pc |>
  filter(country == "GBR", level == "TL3", year == year_to_use,
         str_detect(region, "^UKI")) |>
  arrange(desc(gdp_pc))
print(london_tl3)

# Calculate UK excluding ALL London TL3 regions
uk_excl_london <- data_tl3 |>
  filter(country == "GBR") |>
  filter(!str_detect(region, "^UKI")) |>
  summarise(
    total_gdp = sum(gdp_millions),
    total_pop = sum(pop),
    gdp_pc = (total_gdp * 1e6 / total_pop) / 1000,
    n_regions = n()
  )

cat("\n=== UK excluding all Greater London ===\n")
cat("GDP per capita:", round(uk_excl_london$gdp_pc, 1), "thousand USD PPP\n")
cat("Number of regions:", uk_excl_london$n_regions, "\n")

# Mississippi at TL3 (it's a state, so might be the same as TL2)
ms_tl3 <- data_tl3 |>
  filter(str_detect(region, "US28"))

cat("\n=== Mississippi regions (TL3) ===\n")
if (nrow(ms_tl3) > 0) {
  print(ms_tl3)
  # Mississippi average
  ms_avg <- (sum(ms_tl3$gdp_millions) * 1e6 / sum(ms_tl3$pop)) / 1000
  cat("\nMississippi average:", round(ms_avg, 1), "k\n")
} else {
  # Fall back to TL2
  ms_tl2 <- gdp_pc |>
    filter(region == "US28", year == year_to_use, level == "TL2")
  cat("Using TL2 data:\n")
  print(ms_tl2)
  ms_avg <- ms_tl2$gdp_pc
}

cat("\n=== FINAL VERDICT (TL3 Analysis) ===\n")
uk_without <- uk_excl_london$gdp_pc
cat("UK excluding Greater London:", round(uk_without, 1), "k\n")
cat("Mississippi:", round(ms_avg, 1), "k\n")
cat("Difference:", round(uk_without - ms_avg, 1), "k\n")

if (uk_without < ms_avg) {
  cat("\n✓ CLAIM VERIFIED: UK without London is poorer than Mississippi\n")
} else {
  cat("\n✗ CLAIM NOT FULLY SUPPORTED in current data\n")
  cat("  However, they are very close - the FT may have used\n")
  cat("  different year data or methodology\n")
}

# Additional analysis: show the UK regions that fall below Mississippi
cat("\n=== UK TL3 Regions Below Mississippi Level ===\n")
below_ms <- data_tl3 |>
  filter(country == "GBR", gdp_pc < ms_avg) |>
  arrange(gdp_pc)
cat("Number of UK regions below Mississippi:", nrow(below_ms), "\n")
print(below_ms)

# Show distribution
cat("\n=== GDP per capita distribution ===\n")
summary_stats <- data_tl3 |>
  filter(country == "GBR") |>
  summarise(
    min = min(gdp_pc),
    q25 = quantile(gdp_pc, 0.25),
    median = median(gdp_pc),
    mean = mean(gdp_pc),
    q75 = quantile(gdp_pc, 0.75),
    max = max(gdp_pc)
  )
cat("UK TL3 regions:\n")
print(summary_stats)

# Save for visualization
saveRDS(
  list(
    gdp_pc = gdp_pc,
    uk_excl_london = uk_excl_london,
    ms_avg = ms_avg,
    year = year_to_use
  ),
  "analysis_data.rds"
)
