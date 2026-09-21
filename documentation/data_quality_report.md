# Data Quality Report

## Why I reviewed the data

Before analysing sales performance or building a dashboard, I wanted to make sure the underlying data could be trusted. A polished dashboard is not very useful if records are missing, labels do not match or dates do not make sense.

I reviewed the accounts, products, sales teams and sales pipeline tables for missing information, duplicate records, inconsistent labels and broken relationships. The checks are documented in [`sql/03_data_quality.sql`](../sql/03_data_quality.sql).

## What I found at a glance

The good news is that the dataset is in strong shape overall. All four source files were loaded completely, every primary identifier is unique, and the dates and values follow the expected sales process.

I found only three labels that need to be tidied up:

- `GTXPro` should be written as `GTX Pro` in 1,480 sales opportunities.
- `technolgy` should be corrected to `technology` in 12 account records.
- `Philipines` should be corrected to `Philippines` in one account record.

I also found blank fields among open opportunities. These are not mistakes. They represent information that would not exist yet—for example, an opportunity that is still open cannot have a final closing date or selling price. I will keep those records and preserve the blanks as `NULL` values.

## Did every record make it into the database?

Yes. After resolving the pipeline import issue described in the project log, the database counts matched the original files exactly.

| Table | Expected records | Loaded records | Result |
|---|---:|---:|---|
| `raw_accounts` | 85 | 85 | Complete |
| `raw_products` | 7 | 7 | Complete |
| `raw_sales_teams` | 35 | 35 | Complete |
| `raw_sales_pipeline` | 8,800 | 8,800 | Complete |

This confirmed that the revised import preserved all 2,089 open opportunities that were missing from the initial direct import.

## Did I find any duplicates?

No duplicate identifiers appeared in any of the four tables.

| Identifier checked | Duplicates found |
|---|---:|
| Opportunity ID | 0 |
| Account name | 0 |
| Product name | 0 |
| Sales-agent name | 0 |

Each opportunity, account, product and sales agent can therefore be identified clearly. No records need to be removed as duplicates.

## What was missing—and did it make sense?

### Sales opportunities

At first glance, the pipeline has several blank fields:

| Field | Missing records | Share of pipeline |
|---|---:|---:|
| Opportunity ID | 0 | 0.0% |
| Sales agent | 0 | 0.0% |
| Product | 0 | 0.0% |
| Account | 1,425 | 16.2% |
| Deal stage | 0 | 0.0% |
| Engagement date | 500 | 5.7% |
| Close date | 2,089 | 23.7% |
| Close value | 2,089 | 23.7% |

The important question was not simply, “Are values missing?” It was, “Are they missing where we would reasonably expect them to be?” Breaking the results down by deal stage answered that question.

| Deal stage | Records | Missing account | Missing engagement date | Missing close date | Missing close value |
|---|---:|---:|---:|---:|---:|
| Engaging | 1,589 | 1,088 | 0 | 1,589 | 1,589 |
| Lost | 2,473 | 0 | 0 | 0 | 0 |
| Prospecting | 500 | 337 | 500 | 500 | 500 |
| Won | 4,238 | 0 | 0 | 0 | 0 |

Every completed opportunity has an account, engagement date, closing date and closing value. The blank closing information belongs entirely to open opportunities, which is exactly where it should appear.

The 500 Prospecting opportunities do not have engagement dates because customer engagement has not started yet. Some open opportunities also have no account name, most likely because the prospect has not yet been connected to a formal customer account.

I will keep these blanks as `NULL`. In the dashboard, I may display unnamed accounts as **Unassigned / Not yet identified** so the meaning is clear, but I will not turn that label into a real account in the data model.

### Parent companies

Seventy of the 85 accounts do not have a parent company listed. That is reasonable because `subsidiary_of` applies only when a business is actually a subsidiary. These blanks will also remain `NULL`.

## Does the sales process make sense?

I checked the records against a few basic rules we would expect the sales process to follow. Every test passed.

| Question checked | Problems found |
|---|---:|
| Completed opportunities missing dates or values | 0 |
| Open opportunities already containing closing information | 0 |
| Engaging opportunities missing an engagement date | 0 |
| Prospecting opportunities already containing an engagement date | 0 |
| Opportunities closing before engagement | 0 |
| Won deals with a zero or negative value | 0 |
| Lost deals incorrectly showing revenue | 0 |
| Unfamiliar deal stages | 0 |

The four stages—Prospecting, Engaging, Won and Lost—are used consistently. The dates and values also follow a logical progression from initial prospecting to a completed outcome.

## Do the tables connect properly?

For the most part, yes. Every sales agent named in the pipeline appears in the sales-team roster, every named pipeline account appears in the accounts table, and every listed parent company can be matched to an account.

### One product name does not match

The main relationship problem involves `GTXPro`. That label appears in 1,480 pipeline records, but the product catalogue uses `GTX Pro`, with a space. At the same time, the catalogue version appears to have no sales activity when the tables are matched exactly.

This strongly suggests that both labels refer to the same product. If I leave the mismatch unresolved, those 1,480 opportunities will disappear from product-level comparisons and their revenue will not be assigned to the correct product.

I will standardize `GTXPro` to `GTX Pro` in the cleaned data. The original raw value will remain untouched so the change is fully traceable.

### Five agents have no opportunities

The sales-team roster includes five agents who do not appear in the pipeline:

- Mei-Mei Johns — Central
- Elizabeth Anderson — East
- Natalya Ivanova — East
- Carol Thompson — West
- Carl Lin — West

This does not necessarily mean the roster is wrong. They may be new employees, inactive staff or simply outside the period covered by the opportunity data. I will keep them in the sales-team table so the full team structure is preserved. When comparing performance, I will make it clear that they have zero recorded activity rather than missing personnel information.

## Are the category labels consistent?

I found two straightforward spelling errors in the accounts table:

| Field | Original value | Corrected value | Records affected |
|---|---|---|---:|
| Sector | `technolgy` | `technology` | 12 |
| Office location | `Philipines` | `Philippines` | 1 |

Both will be corrected in the cleaned data. The source tables will stay exactly as they were imported. The sales-team regions are already consistent: Central, East and West.

## Do the numbers look reasonable?

The numerical ranges are broad, but none immediately suggests an impossible or corrupted value.

| Measure | Minimum | Maximum | My assessment |
|---|---:|---:|---|
| Year established | 1979 | 2017 | Reasonable |
| Account revenue (millions) | 4.54 | 11,698.03 | Wide, but possible across different company sizes |
| Employees | 9 | 34,288 | Wide, but possible across different company sizes |
| Suggested product price | 55 | 26,768 | Reasonable across different product tiers |
| Won deal value | 38 | 30,288 | Reasonable given the product-price range |

Engagement dates run from October 20, 2016, to December 27, 2017. Closing dates run from March 1 to December 31, 2017.

Completed sales cycles range from 1 to 138 days. Won opportunities take an average of 51.8 days, compared with 41.5 days for lost opportunities. There are no negative sales cycles. The shortest and longest cycles may be worth exploring later, but there is no evidence that they should be deleted as errors.

## How closely do selling prices match suggested prices?

For the six products that matched the catalogue before cleaning, average selling prices stayed remarkably close to their suggested prices.

| Product | Suggested price | Won deals | Average selling price | Average price realization |
|---|---:|---:|---:|---:|
| GTK 500 | 26,768 | 15 | 26,707.47 | 99.8% |
| GTX Basic | 550 | 915 | 545.64 | 99.2% |
| GTX Plus Basic | 1,096 | 653 | 1,080.05 | 98.5% |
| GTX Plus Pro | 5,482 | 479 | 5,489.88 | 100.1% |
| MG Advanced | 3,393 | 654 | 3,388.97 | 99.9% |
| MG Special | 55 | 793 | 55.19 | 100.3% |

Small differences are normal and could reflect discounts or negotiated premiums. I will keep the actual selling prices rather than replacing them with catalogue prices. `GTX Pro` will join this comparison once its name has been standardized.

## What I will change—and what I will leave alone

| Finding | What it means | Decision |
|---|---|---|
| `GTXPro` | Product name does not match the catalogue | Change to `GTX Pro` |
| `technolgy` | Sector name is misspelled | Change to `technology` |
| `Philipines` | Country name is misspelled | Change to `Philippines` |
| Open opportunities have no closing details | The deals have not closed yet | Keep as `NULL` |
| Prospecting opportunities have no engagement dates | Engagement has not started yet | Keep as `NULL` |
| Some open opportunities have no account | The customer may not yet be formally identified | Keep as `NULL`; clarify only when displaying it |
| Most accounts have no parent company | The field does not apply to every company | Keep as `NULL` |
| Five agents have no opportunities | They have no recorded activity in this dataset | Keep them in the team table |
| Selling prices differ slightly from suggested prices | Normal commercial variation | Keep the actual values |
| Sales cycles range from 1 to 138 days | Valid variation worth exploring later | Keep every record |

## Where this leaves the project

The data is reliable enough to move forward. I found no duplicate IDs, missing information on completed deals, impossible date sequences, unfamiliar stages or broken agent and account relationships.

The cleaning stage is therefore quite focused: I need to standardize three text labels while leaving valid business variation and structurally missing information alone.

The next step is to apply these decisions in `sql/04_data_cleaning.sql`. That script will create a clean analytical layer without changing the raw source tables, so every adjustment remains transparent and reproducible.
