# Fact-Checking the FT Chart: "Britain's economy is highly London-centric"

This repository documents an AI-assisted fact-check of a Financial Times chart claiming that "Without the capital, the UK would be poorer per head than Mississippi."

## Conversation Log

Below is the complete conversation between the user and Claude Code (Opus 4.5) that produced this analysis.

---

### Prompt 1 (User)

```
/init
```

*(This command analyzes the codebase and creates a CLAUDE.md file)*

### Response 1 (Claude)

This repository currently only contains a single image file (`britain-economy.jpeg`) showing an FT analysis of subnational GDP per capita across the UK, Germany, Netherlands, and US. There is no code, build system, or existing documentation to analyze.

Given this is essentially an empty repository with just one data visualization image, creating a CLAUDE.md file wouldn't be useful at this point. A CLAUDE.md file is most valuable when there's:
- Code with build/test/lint commands
- An architecture to document
- Development workflows to explain

Would you like me to:
1. Create a minimal placeholder CLAUDE.md that can be expanded as the project grows
2. Wait until there's actual code in the repository before creating documentation

What direction is this project heading? Understanding the intended purpose would help me provide more relevant guidance.

---

### Prompt 2 (User)

```
Fact check the claims in the image; use R / tidyverse / native pipe. If you can, reproduce the image by getting the required data. If you can't, show what's wrong.
```

### Response 2 (Claude)

I'll fact-check this FT chart by getting OECD regional GDP data and analyzing it with R. Let me set up the analysis.

*(Claude then proceeded to:)*

1. **Set up R environment** - Verified R 4.5.2 and tidyverse were available
2. **Attempted multiple OECD API endpoints** - Tried various SDMX REST API URL formats
3. **Successfully downloaded data** - Used OECD.CFE.EDS DSD_REG_ECO@DF_GDP dataflow version 1.0
4. **Calculated GDP per capita** - Joined GDP (USD PPP, millions) with population data
5. **Analyzed the claim** - Compared UK excluding London to Mississippi

#### Key Findings (2019 OECD data):

| Metric | Value (thousands USD PPP) |
|--------|---------------------------|
| UK national average | 46.8 |
| UK excluding Greater London | 41.4 |
| Mississippi | 37.1 |

#### Verdict: **Claim NOT fully supported**

Using current OECD data, the UK excluding Greater London ($41.4k) is still **$4.3k higher** than Mississippi ($37.1k).

#### Important Caveats:

1. **The numbers are close** - the gap is only ~12%
2. **75 of 170 UK TL3 regions** (44%) are below Mississippi's level
3. **The FT likely used older data** - their chart may reflect pre-2019 figures when the UK was weaker relative to US states
4. **Different PPP base years** or methodology could account for the discrepancy

#### What the data DOES confirm:

- **Britain IS highly London-centric** - London's GDP per capita (~$80k) is nearly double the UK average excluding London ($41.4k)
- **The UK has much greater regional inequality** than Germany, Netherlands, or the US
- **Many UK regions are genuinely poor** by developed-country standards

The reproduced chart is saved to `ft_chart_reproduction.png`. The R scripts are in:
- `fact_check.R` - data download and analysis
- `reproduce_chart.R` - visualization

Sources:
- [OECD Regional Economy Database](https://data-explorer.oecd.org/)
- [DBnomics OECD Regional GDP](https://db.nomics.world/OECD/DSD_REG_ECO@DF_GDP)

---

### Prompt 3 (User)

```
Please create a README.md file that includes all of the prompts I have given you and your responses to me. I want to document exactly how you came to produce these results. Include this final prompt in the file.
```

### Response 3 (Claude)

*(This README.md file)*

---

## Files in This Repository

| File | Description |
|------|-------------|
| `britain-economy.jpeg` | Original FT chart being fact-checked |
| `fact_check.R` | R script for downloading and analyzing OECD data |
| `reproduce_chart.R` | R script for reproducing the FT visualization |
| `ft_chart_reproduction.png` | Reproduced chart using OECD 2019 data |
| `oecd_regional_gdp.rds` | Cached OECD regional GDP data |
| `oecd_regional_gdp.csv` | CSV version of the OECD data |
| `analysis_data.rds` | Processed analysis results |
| `README.md` | This documentation file |

## How to Reproduce

```r
# Run the fact-check analysis
source("fact_check.R")

# Generate the visualization
source("reproduce_chart.R")
```

## Technical Details

### Data Source
- **Dataset**: OECD Regional Economy (DSD_REG_ECO@DF_GDP)
- **API**: OECD SDMX REST API v1.0
- **Measure**: GDP in millions USD PPP (current prices)
- **Population**: Regional population counts
- **Geographic levels**: TL2 (large regions) and TL3 (small regions)
- **Year**: 2019 (pre-COVID)

### Methodology
1. Downloaded regional GDP and population from OECD
2. Calculated GDP per capita = (GDP in millions × 1,000,000) / population / 1,000
3. For UK, excluded all Greater London regions (UKI* prefix) at TL3 level
4. Compared population-weighted average to Mississippi (US28)

### Key Code (Native Pipe)

```r
# Calculate UK excluding Greater London
uk_excl_london <- data_tl3 |>
  filter(country == "GBR") |>
  filter(!str_detect(region, "^UKI")) |>
  summarise(
    total_gdp = sum(gdp_millions),
    total_pop = sum(pop),
    gdp_pc = (total_gdp * 1e6 / total_pop) / 1000
  )
```

## Conclusion

The FT's claim that "Without the capital, the UK would be poorer per head than Mississippi" is **not fully supported by current (2019) OECD data**, though the numbers are close. The UK without London ($41.4k) remains above Mississippi ($37.1k) by about $4.3k.

However, the broader point about Britain's London-centricity is well-supported: London's GDP per capita is nearly double the rest of the UK, and 44% of UK regions fall below Mississippi's level.

---

*Analysis conducted by Claude Code (Opus 4.5) on December 18, 2025*
