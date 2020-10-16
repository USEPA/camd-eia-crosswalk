# CAMD - EIA Crosswalk
A data crosswalk to integrate U.S. power sector emission and operation data. Provided in this repo are both the outputs of the crosswalk (csv and xlsx format) as well as the R script (in an R markdown document) that generates these outputs.

>**Notice**: This is a work in progress. CAMD continues to refine its methodology and quality assurance procedures and will provide information on updates as necessary.


## Background
___
The U.S. Environmental Protection Agency’s (EPA’s) Clean Air Markets Division (CAMD) and the U.S. Energy Information Administration (EIA) provide two of the most comprehensive and commonly used datasets covering the electric power sector. These two datasets include information on emissions, electricity generation, fuel consumption, operations, and facility attributes of power plants across the United States. Many researchers and data consumers find useful details in both datasets, rather than just one on its own. However, key differences in the purpose and manner of data collection by these agencies contribute to difficulties in merging the two datasets. In providing this crosswalk, which relates key identifiers assigned to power plant units, CAMD is hoping to make it easier to connect and use both datasets.

The crosswalk is available as a spreadsheet (xlsx) and comma-delimited text file (csv) for those who are just looking to connect the two datasets. The code for making the crosswalk from the two datasets is also available for those interested in how it was made or adapting it. Please see “Contributing to the Crosswalk” for more information on how to improve it.

### What facilities are included in each dataset?
Generally speaking, CAMD collects the [Power Sector Emissions Data](https://www.epa.gov/airmarkets/power-sector-emissions-data) from fossil fuel-fired electric generating units (EGUs) greater than 25 MW in capacity. EIA collects data on all EGUs (including nuclear and renewables) that are over 1 MW in capacity and connected to the grid.

### How are these data collected?
EGUs that submit data to CAMD generally use continuous emissions monitoring systems (CEMS), or alternatives that continuously measure ey paramaters, and data acquisition and handling system to collect emissions and operations data. EGUs submit the hourly data to CAMD every calendar quarter using EPA-provided data validation and reporting software. EGUs submit data to EIA through various surveys with various reporting periods.

### Why are these data collected?
CAMD is authorized to collect the [Power Sector Emissions Data](https://www.epa.gov/airmarkets/power-sector-emissions-data) to ensure compliance with certain EPA and state air quality regulatory programs that cover the electric power sector. EIA is authorized to collect a variety of energy data to provide independent analysis to the public.

### What is the temporal resolution of each dataset?
CAMD collects data at the hourly level. Power plants submit these data to EPA quarterly, and they are made available to the public through a variety of tools within one month of the end of each calendar quarter. The temporal resolution of EIA data depends on the survey form in which the data are collected. Generally, EIA provides monthly and annual data and hourly regional aggregated generation (but not hourly emissions).

### What is the lowest level of spatial aggregation for each dataset?
CAMD and EIA both collect unit-level data. However, there is often confusion about what CAMD considers a “unit” versus what EIA considers a “unit.”

In general, a steam power plant has a boiler that combusts fuel used to produce steam, the energy of the steam is used to rotate a steam turbine, and a generator that converts the kinetic energy of rotation into electrical energy (refer to Figure 1.A below). Because CAMD’s purpose for collecting data is environmental compliance, CAMD considers the source of emissions, the boiler, to be a unit. On the other hand, EIA is primarily focused on collecting data on electrical generation, so EIA considers the source of electricity, the generator, to be a unit. While many power plants have a one-to-one relationship between boilers and generators, many do not. As in Figure 1.B below, there could be two (or more) boilers that serve one generator. In CAMD’s database, this power plant would have two units (two boilers); in EIA’s database, this power plant would have list only one unit (one generator).

Like steam power plants, gas turbines can also have one-to-one relationships (Figure 1.C) or complex configurations. Figure 1.D illustrates a common natural gas combined cycle configuration with multiple gas turbines providing excess heat to a single steam turbine. In CAMD’s database, the plant in Figure 1.D would list two units (two gas turbines); in EIA’s database, this plant would list three units (two gas turbines and one steam turbine).

*<div align="center">Figure 1. Fossil Fuel-Fired Power Plant Diagrams</div>*
![Figure 1. Fossil Fuel-Fired Power Plant Diagrams](/images/figure1.png)

The power plant is identified by an Office of Regulatory Information Systems Plant Location code (ORISPL or ORIS), a unique facility identifier that typically does not change over the life of the plant. ORIS codes are consistent between CAMD and EIA (with a few exceptions, see “Methodology” for more information). The boiler and the generator have separate IDs. These IDs may be the same (for example, the boiler ID in Figure 1.A may be listed as 1 with the associated generator ID also listed as 1), but they may not be, which creates difficulties in joining CAMD and EIA data. In addition, the IDs for the same plant component may differ between the two datasets due to reporting inconsistencies.

In this crosswalk, CAMD matches the boiler ID (or unit ID) reported to CAMD to its corresponding EIA generator ID via  the “generator ID” reported to CAMD. Though the vast majority of CAMD data is publicly accessible, the CAMD generator ID is not easily accessible. Therefore, it may have been difficult for researchers and data consumers to find and access the data.

For more information on CAMD’s Power Sector Emissions Data, refer to https://www.epa.gov/airmarkets/power-sector-emissions-data.

For more information on EIA’s electricity data, refer to https://www.eia.gov/electricity/data/guide/. 

### How do I cite the crosswalk data?
Huetteman, Justine; Tafoya, Johnathan; Johnson, Travis; and Schreifels, Jeremy. 2020. EIA-EPA Power Sector Data Crosswalk.


## Methodology
___
The crosswalk code retrieves the CAMD ORIS, combustion unit ID, generator ID, and other data using the [Field Audit Checklist Tool (FACT) API](https://www.epa.gov/airmarkets/field-audit-checklist-tool-fact-api). The API returns data in JSON format. The crosswalk code then retrieves the EIA-860 plant ID, boiler ID, generator ID, and other data from the EIA-860 zip file and processes the worksheets. Based on 2018 data, the code matches CAMD ORIS and generator ID to the EIA plant ID and generator ID. Approximately 93% of generators are matched based on generator ID. An additional 3% are matched using fuzzy matching, which attempts to match generators with the same ORIS code and similar generator IDs (e.g., 6 and NO.6) using different rules to generate matches. The remaining 4% of generators are unmatched: 2% must be addressed manually and 2% do not have an associated generator ID in CAMD’s data (refer to “Important Notes” section below).

In rare instances, the ORIS/plant codes do not match in CAMD and EIA’s databases. These discrepancies were discovered through the production of [eGRID](https://www.epa.gov/egrid) and are regularly tracked and updated with new eGRID releases. In the crosswalk code, these discrepancies are accounted for before any matching occurs. In the code, CAMD changes EIA’s plant code to match CAMD’s ORIS code and includes a field indicating that the plant code is a known mismatch (“PLANT_CODE_CHANGE_FLAG”).

The resulting crosswalk lists all boilers and generators in CAMD’s database with its corresponding EIA generator. Generators listed in EIA data that are not matched to CAMD data are omitted. CAMD added a field “MATCH_TYPE” indicating how the generators were matched. The fields included in the final crosswalk from each database include: ORIS (plant) code, generator ID, boiler ID (EIA), unit ID (EPA), plant name, state, latitude, longitude, primary fuel type, and nameplate capacity. The corresponding boiler (unit) ID from CAMD is also included.

For more information on CAMD’s FACT API and to sign up for an API key, refer to https://www.epa.gov/airmarkets/field-audit-checklist-tool-fact-api#/.

For more information on the EIA-860, refer to https://www.eia.gov/electricity/data/eia860/.


## Important Notes
___
* There may be multiple generators associated with one boiler, or multiple boilers associated with one generator. CAMD recommends that data consumers trying to match information (e.g., emissions and generation) from both datasets first decide whether to collapse on boilers or generators to avoid double counting.

* The crosswalk excludes units that retired prior to 2018 and units that commenced operation after 2018. If a data consumer needs a matching list for earlier data, CAMD recommends modifying the R code to use a different data year and operating boundaries. 

* CAMD generator IDs are often entered by EPA staff based on their research. However, some units in CAMD’s database do not have a generator ID. This may be because staff have not identified a known match or that the unit does not send electricity to the grid (e.g., it is an industrial unit that is affected by one of EPA’s regulatory programs but isn't required to report to EIA). These units would not be matched to EIA in the crosswalk. Many of these units have an ORIS code that starts with 88 followed by four digits; however, not all non-grid-connected facilities follow this practice. CAMD staff will continue to fill in gaps as more information beceomes available. Those updates will immediately update the FACT API results. If you notice additional units when re-running the code, it could be due to this ongoing process. 

* CAMD plans to add code for manual matching of units that are unable to be matched through automated processes at a later time.


## Contributing to the Crosswalk
___
Thanks for taking the time to contribute!

### Getting Started
The data for this crosswalk can be found from these two sources:
* EIA dataset: [EIA-860](https://www.eia.gov/electricity/data/eia860/) 
   * Zip file with several xlsx files. Namely, we use "2___Plant_Y2018.xlsx”, “3_1_Generator_Y2018.xlsx”, and "6_1_EnviroAssoc_FY2018.xlsx".
* CAMD dataset: [Field Audit Checklist Tool (FACT) API](https://www.epa.gov/airmarkets/field-audit-checklist-tool-fact-api#/)
   * REST API with various endpoints. We use the /facilities endpoint.
   * Must sign up for an API key [here](https://www.epa.gov/airmarkets/field-audit-checklist-tool-fact-api#signup).
* ORIS/Plant ID Changes: Section 4.1.1 [eGRID Technical Support Document](https://www.epa.gov/egrid/egrid-technical-support-document)
   * See  Table C-5. [Crosswalk of EIA ORISPL ID changes to EPA/CAMD ORISPL IDs](https://www.epa.gov/egrid/egrid-technical-support-document)
   * Direct link to xlsx: [epa-eia_plant_id_crosswalk.xlsx](https://www.epa.gov/sites/production/files/2020-09/epa-eia_plant_id_crosswalk.xlsx)

The crosswalk script is built using R with [tidyverse](https://www.tidyverse.org/) packages and [styling](https://style.tidyverse.org/).

### Issues
Ensure the issue was not already reported by searching on Github under [issues](https://github.com/USEPA/camd-eia-crosswalk/issues). If you’re unable to find an open issue addressing the bug, [open a new issue](https://github.com/USEPA/camd-eia-crosswalk/issues/new/choose).

When writing an issue please write detailed information to help us understand the issue.

For example: 
* The ORIS_CODE and GENID associated with the issue. 
* The step where the issue occurs (e.g., Step 2c).
* The expected and actual results.
* Any additional data that may be helpful to improve the rule for the step.

### Pull Requests
Pull requests are always welcome!
* When you edit the code, please style according to the [tidyverse styling guide](https://style.tidyverse.org/) (the [styler](https://styler.r-lib.org/) R package is useful to select and style statements).
* Ensure the pull request description clearly describes the problem and solution

## Disclaimer
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
