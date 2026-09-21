# Data Quality Report

## Project Overview

This report summarizes the data-quality assessment completed for the MavenTech B2B Sales Pipeline Analytics project. The review covered the four source tables—accounts, products, sales teams and sales opportunities—before any cleaning or business analysis was performed.

The assessment focused on completeness, uniqueness, validity, consistency and relational integrity. All results were produced using the diagnostic queries in [`sql/03_data_quality.sql`](../sql/03_data_quality.sql).

## Executive Summary

The dataset is generally well structured and suitable for analysis. All four source files were fully loaded, primary identifiers are unique, closed opportunities contain the required dates and values, and no invalid stage or date combinations were found.

Three label inconsistencies require standardization:

- `GTXPro` should match the catalogue label `GTX Pro` in 1,480 pipeline records.
- `technolgy` should be corrected to `technology` in 12 account records.
- `Philipines` should be corrected to `Philippines` in one account record.

The missing fields in open opportunities are expected rather than erroneous. They reflect information that is not yet available because the opportunities have not progressed or closed. These records will be retained.

## 1. Source Reconciliation

The database counts matched the source files after the staged pipeline import.

| Table | Expected records | Loaded records | Result |
|---|---:|---:|---|
| `raw_accounts` | 85 | 85 | Pass |
| `raw_products` | 7 | 7 | Pass |
| `raw_sales_teams` | 35 | 35 | Pass |
| `raw_sales_pipeline` | 8,800 | 8,800 | Pass |

This confirmed that the staging-table solution preserved all 2,089 open opportunities that had been omitted during the initial direct import.

## 2. Duplicate Identifiers

No duplicate primary identifiers were found.

| Identifier checked | Duplicate records | Result |
|---|---:|---|
| Opportunity ID | 0 | Pass |
| Account name | 0 | Pass |
| Product name | 0 | Pass |
| Sales-agent name | 0 | Pass |

No deduplication is required.

## 3. Missing Values

### Sales pipeline

| Field | Missing records | Share of pipeline | Assessment |
|---|---:|---:|---|
| Opportunity ID | 0 | 0.0% | Complete |
| Sales agent | 0 | 0.0% | Complete |
| Product | 0 | 0.0% | Complete |
| Account | 1,425 | 16.2% | Expected for some open opportunities |
| Deal stage | 0 | 0.0% | Complete |
| Engagement date | 500 | 5.7% | Expected for Prospecting opportunities |
| Close date | 2,089 | 23.7% | Expected for open opportunities |
| Close value | 2,089 | 23.7% | Expected for open opportunities |

Breaking the missing values down by stage showed a consistent business pattern:

| Deal stage | Records | Missing account | Missing engagement date | Missing close date | Missing close value |
|---|---:|---:|---:|---:|---:|
| Engaging | 1,589 | 1,088 | 0 | 1,589 | 1,589 |
| Lost | 2,473 | 0 | 0 | 0 | 0 |
| Prospecting | 500 | 337 | 500 | 500 | 500 |
| Won | 4,238 | 0 | 0 | 0 | 0 |

All closed opportunities have an account, engagement date, close date and close value. The missing account names occur only in the open pipeline and most likely represent prospects that have not yet been linked to a formal account record.

These blanks will be preserved as `NULL`. For reporting, unnamed accounts may be displayed as **Unassigned / Not yet identified**, but they will not be converted into a real account member in the data model.

### Accounts

Seventy of the 85 accounts have no parent company listed. This is reasonable because `subsidiary_of` applies only when an account is a subsidiary. The blanks will remain `NULL`.

## 4. Business-Rule Validation

The opportunity records passed every stage, date and value rule tested.

| Validation rule | Exceptions | Result |
|---|---:|---|
| Closed opportunities missing required dates or values | 0 | Pass |
| Open opportunities containing closure information | 0 | Pass |
| Engaging opportunities missing an engagement date | 0 | Pass |
| Prospecting opportunities containing an engagement date | 0 | Pass |
| Close date earlier than engagement date | 0 | Pass |
| Won deals with non-positive values | 0 | Pass |
| Lost deals with non-zero values | 0 | Pass |
| Unrecognized deal stages | 0 | Pass |

The four valid stages are Prospecting, Engaging, Won and Lost.

## 5. Relational Integrity

### Confirmed product mismatch

The pipeline contains 1,480 opportunities recorded as `GTXPro`, while the product catalogue contains `GTX Pro`. The catalogue version has no exact-match pipeline activity, strongly confirming that these labels refer to the same product.

This mismatch would prevent those opportunities from joining to the product table and would understate product-level revenue, conversions and activity if left unresolved.

**Treatment:** Standardize `GTXPro` to `GTX Pro` in the cleaned analytical layer. Preserve the original value in the raw table.

### Other relationship checks

| Check | Finding | Assessment |
|---|---|---|
| Pipeline agents absent from roster | None | Pass |
| Named pipeline accounts absent from account table | None | Pass |
| Parent companies absent from account table | None | Pass |
| Catalogue products with no exact-match activity | `GTX Pro` | Explained by `GTXPro` mismatch |
| Accounts with no opportunities | None | Pass |

Five rostered sales agents have no recorded opportunities:

- Mei-Mei Johns — Central
- Elizabeth Anderson — East
- Natalya Ivanova — East
- Carol Thompson — West
- Carl Lin — West

This is not automatically a data defect. The roster may include inactive, newly hired or out-of-period employees. The agents will remain in the sales-team dimension so the model preserves the complete organizational structure. Any performance ranking should distinguish between zero activity and missing personnel data.

## 6. Category Consistency

Two spelling inconsistencies were identified in the accounts table:

| Field | Source value | Standardized value | Affected records |
|---|---|---|---:|
| Sector | `technolgy` | `technology` | 12 |
| Office location | `Philipines` | `Philippines` | 1 |

**Treatment:** Correct both values in the cleaned analytical layer while preserving the raw source table unchanged.

No unexpected values were found in the regional-office field; the valid categories are Central, East and West.

## 7. Range and Plausibility Review

### Accounts and products

| Measure | Minimum | Maximum | Assessment |
|---|---:|---:|---|
| Year established | 1979 | 2017 | Plausible |
| Account revenue (millions) | 4.54 | 11,698.03 | Wide but plausible |
| Employees | 9 | 34,288 | Wide but plausible |
| Suggested product price | 55 | 26,768 | Plausible across product tiers |

### Opportunities

| Measure | Minimum | Maximum | Assessment |
|---|---:|---:|---|
| Engagement date | 2016-10-20 | 2017-12-27 | Valid |
| Close date | 2017-03-01 | 2017-12-31 | Valid |
| Won deal value | 38 | 30,288 | Plausible |

Completed sales cycles range from 1 to 138 days. Won deals average 51.8 days, while lost deals average 41.5 days. No negative durations were found. The short and long cycles may be analytically interesting, but they are within the observed business range and will not be removed as outliers.

## 8. Price Consistency

For the six products that matched the catalogue before cleaning, average realized prices were close to their suggested prices.

| Product | Suggested price | Won deals | Average close value | Average realization |
|---|---:|---:|---:|---:|
| GTK 500 | 26,768 | 15 | 26,707.47 | 99.8% |
| GTX Basic | 550 | 915 | 545.64 | 99.2% |
| GTX Plus Basic | 1,096 | 653 | 1,080.05 | 98.5% |
| GTX Plus Pro | 5,482 | 479 | 5,489.88 | 100.1% |
| MG Advanced | 3,393 | 654 | 3,388.97 | 99.9% |
| MG Special | 55 | 793 | 55.19 | 100.3% |

The variation around suggested prices is consistent with discounts or negotiated premiums. These values will be retained rather than forced to catalogue prices. `GTX Pro` will be added to this comparison after its pipeline label is standardized.

## 9. Cleaning Decisions

| Finding | Classification | Decision |
|---|---|---|
| `GTXPro` product label | Confirmed consistency error | Standardize to `GTX Pro` |
| `technolgy` sector label | Confirmed spelling error | Standardize to `technology` |
| `Philipines` location label | Confirmed spelling error | Standardize to `Philippines` |
| Missing close dates and values in open stages | Expected structural missingness | Retain as `NULL` |
| Missing engagement dates in Prospecting | Expected structural missingness | Retain as `NULL` |
| Missing accounts in open stages | Expected structural missingness | Retain as `NULL`; label only in presentation layer |
| Missing parent company | Optional attribute | Retain as `NULL` |
| Five agents with no opportunities | Valid but noteworthy observation | Retain in sales-team dimension |
| Variance from suggested product prices | Valid business variation | Retain actual close values |
| Sales-cycle range of 1–138 days | Valid but noteworthy observation | Retain all records |

## Conclusion

The quality review found no duplicate keys, missing closed-deal information, invalid opportunity stages, impossible date sequences or broken agent/account relationships. The dataset can proceed to cleaning after three text values are standardized.

The next step is to implement these decisions in `sql/04_data_cleaning.sql`, creating a clean analytical layer while keeping every raw table unchanged and fully traceable to the source files.
