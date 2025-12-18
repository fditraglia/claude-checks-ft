# Reproduce FT Chart: "Britain's economy is highly London-centric"
# Using OECD regional accounts data

library(tidyverse)
library(scales)

cat("=== Reproducing FT Chart ===\n\n")

# Load data
df <- readRDS("oecd_regional_gdp.rds")

countries <- c("GBR", "USA", "DEU", "NLD")
country_labels <- c("GBR" = "UK", "USA" = "US", "DEU" = "Germany", "NLD" = "Netherlands")

# Capital region prefixes (for excluding entire capital regions)
capital_prefixes <- c(
  "GBR" = "UKI",    # Greater London
  "DEU" = "DE30",   # Berlin (at TL3 it's DE300)
  "NLD" = "NL32",   # Noord-Holland (Amsterdam)
  "USA" = "US11"    # DC
)

# Get GDP in millions USD PPP
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
  filter(COUNTRY %in% countries, MEASURE == "POP") |>
  select(country = COUNTRY, region = REF_AREA, level = TERRITORIAL_LEVEL,
         year = TIME_PERIOD, pop = OBS_VALUE)

# Calculate GDP per capita
gdp_pc <- gdp_total |>
  inner_join(pop_data, by = c("country", "region", "level", "year")) |>
  mutate(gdp_pc = (gdp_millions * 1e6 / pop) / 1000)

# Use 2019 data
year_to_use <- 2019

# Use TL3 for UK/Germany/NLD, TL2 for US
data_plot <- gdp_pc |>
  filter(year == year_to_use) |>
  filter(
    (country %in% c("GBR", "DEU", "NLD") & level == "TL3") |
    (country == "USA" & level == "TL2")
  ) |>
  mutate(
    country_label = country_labels[country],
    is_capital = case_when(
      country == "GBR" ~ str_detect(region, "^UKI"),
      country == "DEU" ~ str_detect(region, "^DE30"),
      country == "NLD" ~ str_detect(region, "^NL32"),
      country == "USA" ~ region == "US11",
      TRUE ~ FALSE
    )
  )

# Calculate national averages
national_avg <- data_plot |>
  group_by(country, country_label) |>
  summarise(
    national_avg = (sum(gdp_millions) * 1e6 / sum(pop)) / 1000,
    n_regions = n(),
    .groups = "drop"
  )

# Calculate average excluding ENTIRE capital region (all sub-regions)
without_capital <- data_plot |>
  filter(!is_capital) |>
  group_by(country, country_label) |>
  summarise(
    avg_excl_capital = (sum(gdp_millions) * 1e6 / sum(pop)) / 1000,
    n_regions_excl = n(),
    .groups = "drop"
  )

summaries <- national_avg |>
  left_join(without_capital, by = c("country", "country_label"))

cat("Summary statistics:\n")
print(summaries)

# Mississippi value
mississippi <- gdp_pc |>
  filter(region == "US28", year == year_to_use, level == "TL2") |>
  pull(gdp_pc)

cat("\nMississippi GDP per capita:", round(mississippi, 1), "k\n")

# Create the plot
p <- ggplot() +
  # Points for each region, sized by population
  geom_point(
    data = data_plot,
    aes(x = country_label, y = gdp_pc, size = pop / 1e6,
        color = is_capital),
    alpha = 0.5
  ) +
  scale_color_manual(values = c("FALSE" = "gray50", "TRUE" = "#D9534F"),
                     guide = "none") +
  # National average line (blue)
  geom_segment(
    data = summaries,
    aes(x = as.numeric(factor(country_label)) - 0.3,
        xend = as.numeric(factor(country_label)) + 0.3,
        y = national_avg, yend = national_avg),
    color = "#4A90D9",
    linewidth = 1.5
  ) +
  # Average excluding capital (red)
  geom_segment(
    data = summaries,
    aes(x = as.numeric(factor(country_label)) - 0.3,
        xend = as.numeric(factor(country_label)) + 0.3,
        y = avg_excl_capital, yend = avg_excl_capital),
    color = "#D9534F",
    linewidth = 1.5
  ) +
  # Mississippi reference line
  geom_hline(yintercept = mississippi, linetype = "dashed", color = "gray40") +
  annotate("text", x = 4.3, y = mississippi, label = "Mississippi",
           hjust = 0, size = 3, color = "gray40") +
  # Log scale
  scale_y_log10(
    breaks = c(30, 40, 50, 60, 70, 80, 90, 100, 150),
    limits = c(20, 200)
  ) +
  scale_size_continuous(range = c(1, 10), guide = "none") +
  # Labels
  labs(
    title = "Britain's economy is highly London-centric. Without the capital,",
    subtitle = "the UK would be poorer per head than Mississippi",
    caption = paste0("Subnational GDP per capita ('000s of US dollars, PPP-adjusted, log scale)\n",
                    "Source: OECD regional accounts data, ", year_to_use, "\n",
                    "Blue line: National average | Red line: Average excluding entire capital region\n",
                    "Red dots: Capital region sub-areas"),
    x = NULL,
    y = "GDP per capita (thousands USD PPP)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 12),
    plot.caption = element_text(hjust = 0, size = 8),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank()
  )

# Save plot
ggsave("ft_chart_reproduction.png", p, width = 10, height = 7, dpi = 150)
cat("\nChart saved to ft_chart_reproduction.png\n")

# Print the key finding
cat("\n" , strrep("=", 60), "\n")
cat("                    FACT CHECK RESULTS\n")
cat(strrep("=", 60), "\n\n")

uk_data <- summaries |> filter(country == "GBR")
cat("UK national average:        ", sprintf("%5.1f", uk_data$national_avg), "k USD PPP\n")
cat("UK excluding Greater London:", sprintf("%5.1f", uk_data$avg_excl_capital), "k USD PPP\n")
cat("Mississippi:                ", sprintf("%5.1f", mississippi), "k USD PPP\n")
cat("\n")

if (uk_data$avg_excl_capital < mississippi) {
  cat("✓ CLAIM VERIFIED: UK without London is poorer than Mississippi\n")
} else {
  cat("✗ CLAIM NOT SUPPORTED with current (2019) OECD data\n")
  cat("\n")
  cat("UK without London is HIGHER than Mississippi by +",
      round(uk_data$avg_excl_capital - mississippi, 1), "k\n")
}

cat("\n")
cat("However, note that:\n")
cat("- The numbers are relatively close\n")
cat("- The FT may have used older data or different methodology\n")
cat("- The claim may have been accurate at the time of publication\n")

# Show how many UK regions are below Mississippi
below_ms <- data_plot |>
  filter(country == "GBR", gdp_pc < mississippi)
cat("\n")
cat(nrow(below_ms), "out of", nrow(data_plot |> filter(country == "GBR")),
    "UK regions are below Mississippi level\n")
