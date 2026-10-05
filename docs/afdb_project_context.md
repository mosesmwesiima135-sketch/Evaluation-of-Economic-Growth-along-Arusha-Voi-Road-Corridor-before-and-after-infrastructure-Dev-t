# The road project and the AfDB evaluation

This note summarises what is publicly documented about the Arusha–Holili/Taveta–Voi Road Project and how the African Development Bank (AfDB) evaluated it. It gives the context for the results in the main [README](../README.md).

## The project

The Arusha–Holili/Taveta–Voi road is a regional corridor in the East African Community. It connects the Northern Corridor at Voi, in Kenya, to the Central Corridor through the Holili/Taveta border, Arusha, Babati, Dodoma and Singida, in Tanzania. It gives northern Tanzania a shorter route to the port of Mombasa.

| Item | Detail | Source |
|---|---|---|
| Approval | 16 April 2013 | AfDB project portal |
| Financing | AfDB loans of about US$232.5 million, roughly 89% of project cost, with the two governments funding the rest | KHL (2013) |
| Tanzania components | Arusha bypass (42.4 km); dualling of Sakina–Tengeru (14.1 km); two roadside amenities at Tengeru | AfDB project portal |
| Kenya components | Upgrading of Taveta–Mwatate (about 89 km) from gravel to bitumen; Taveta bypass (12 km); roadside amenities at Bura and Maktau | AfDB project portal; KHL (2013) |
| Border facility | One Stop Border Post (OSBP) at Holili/Taveta | EAC |
| Kenya works contract | Mwatate–Taveta upgrading, started February 2014, 36 months | AfDB contract award notice |
| Completion | Kenyan section completed June 2017; Tanzanian components completed April 2019 | EAC |
| Later phase | The Tengeru–Moshi–Holili stretch was left for a second phase, financed by JICA under an agreement signed in 2022 | Global Highways (2022) |

The last row matters for this study. The Usa River–Moshi–Holili section sits inside the corridor but was not upgraded in the AfDB phase, so it serves as an informal comparison section.

## What the AfDB evaluation found

The AfDB's Independent Development Evaluation (IDEV) published *A Decade on the Move: Evaluation of the AfDB's Support for the Transport Sector (2012–2023)* in April 2025. The summary report refers to this road in several findings.

| Theme | Finding on the Arusha–Holili/Taveta–Voi road |
|---|---|
| Transport efficiency | Travel time from Arusha to Mombasa fell from 6 hours to 4 hours, in line with the target |
| Regional integration | After completion in 2019, the regional integration index within the EAC rose from 0.656 (2016) to 0.792 (2019) for Kenya, and from 0.433 to 0.513 for Tanzania |
| Trade facilitation | The Holili–Taveta OSBP is cited as a project that built logistics efficiency into the design |
| Economic activity | Geospatial analysis found the road contributed to a 138.50% increase in nighttime light in Kenya and 80.53% in Tanzania |
| Overall | Listed among the initiatives that spurred local economic growth |

## How IDEV used nighttime lights

The evaluation applied geospatial analysis to six completed projects. It compared nighttime light intensity before and after each project, treating light as a proxy for economic activity, in order to capture indirect benefits such as commercial activity, urban growth and access to markets where formal economic data were limited.

IDEV stated two cautions about that analysis:

- The increase in light could not be attributed solely to the AfDB interventions.
- Geospatial analysis was limited by image resolution and by its inability to account for other explanatory factors, so it could not support definitive conclusions by itself.

## How this study relates to it

| | AfDB IDEV (2025) | This study |
|---|---|---|
| Measure | Nighttime light intensity | VIIRS annual `average_masked` radiance |
| Comparison | Before and after the project | 2013 against the mean of 2020–21 |
| Area | Not specified in the summary report | 10 km each side of the road, 1 km grid |
| Reporting unit | Country (Kenya, Tanzania) | Corridor, four road sections, and individual 1 km cells |
| Spatial model | Not specified in the summary report | BYM2 model in R-INLA |
| Kenya result | +138.50% | +248.4% (sections 3 and 4) |
| Tanzania result | +80.53% | +71.9% (sections 1 and 2) |

**Agreement.** Both find substantial growth in light on both sides of the border, with faster relative growth in Kenya.

**What this study adds.**

- It shows **where** inside the corridor the change happened, cell by cell, instead of a single figure per country.
- It separates **relative** from **absolute** growth. The Kenyan side grew faster in percentage terms because it started from a base about one tenth the size of Tanzania's. In absolute terms the Tanzanian side gained almost three times as much light.
- It compares upgraded and non-upgraded sections. The non-upgraded Usa River–Moshi–Holili section grew by 90.9%, which is direct evidence of the background growth that IDEV's caution refers to.
- The code and data steps are open and reproducible.

**Why the numbers differ.** The two analyses are likely to differ in study area, years, data product and method, and the summary report does not give those details for the IDEV figures. This study also assigns cells to countries by longitude, which only approximates the border.

## Sources

- African Development Bank, Independent Development Evaluation (2025). *A Decade on the Move: Evaluation of the AfDB's Support for the Transport Sector (2012–2023). Summary Report.* April 2025.
- African Development Bank. Project portal: Multinational – Arusha-Holili/Taveta-Voi Road Project. https://projectsportal.afdb.org/dataportal/VProject/show/P-Z1-DB0-075 and https://projectsportal.afdb.org/dataportal/VProject/show/P-Z1-DB0-074
- African Development Bank. Contract award notice: Upgrading of Mwatate–Taveta Road Project (KeNHA).
- East African Community. EAC Road Transport sub-sector Projects. https://www.eac.int/infrastructure/road-transport-sub-sector/projects
- KHL Group (22 April 2013). AfDB funds East African road project. https://www.khl.com/news/afdb-funds-east-african-road-project/84751.article
- Global Highways (2022). Tanzania's work on East Africa's multi-national road project. https://www.globalhighways.com/wh3/wh6/wh8/wh10/feature/tanzanias-work-east-africas-multi-national-road-project
