# Stock Market Portfolio Analysis and Optimization

## Project Overview
Titan Quantitative Strategies (TQS) specializes in creating optimized investment strategies using advanced statistical and financial modeling techniques. This project focuses on constructing and analyzing a custom stock portfolio optimized using the **Mean-Variance (MV) Optimization Model**. The portfolio’s performance is benchmarked against the **S&P 500 Total Return Index (SP500TR)** under historical and forward-looking market conditions.

## Objectives
- Build a 15-stock portfolio optimized for risk and return using the MV optimization framework.
- Compare portfolio performance against the SP500TR benchmark.
- Evaluate portfolio performance using risk-adjusted metrics like Sharpe Ratio, annualized return, and volatility.
- Backtest portfolio performance on out-of-sample data from Q1 2021.

## Key Results
| Metric                 | SP500TR     | Portfolio    |
|------------------------|-------------|--------------|
| **Annualized Return**  | 29.87%      | -10.16%      |
| **Standard Deviation** | 16.23%      | 13.97%       |
| **Sharpe Ratio**       | 1.8399      | -0.7271      |

While the portfolio exhibited lower volatility than the SP500TR, it significantly underperformed in terms of returns, highlighting the limitations of static optimization under dynamic market conditions.

## Repository Structure
Here’s how the repository is organized:

```
📁 Stock-Market-Portfolio-Optimization
├── 📁 data                      # Data files
│    └── database_backup.backup  # Backup of the PostgreSQL database
├── 📁 scripts                   # Source code files
│    ├── analysis.R               # R script for portfolio analysis and optimization
│    ├── database.sql             # SQL script for database schema and queries
├── 📁 docs                      # Documentation and reports
│    └── Project-Report.pdf       # Full project report
├── README.md                     # Project overview and usage guide


## Technology Stack
- **Database:** PostgreSQL
- **Programming Language:** R
- **Tools and Libraries:**
  - RPostgres, DBI: Database interaction
  - PerformanceAnalytics, PortfolioAnalytics: Financial analysis
  - ROI, ROI.plugin.quadprog: Optimization

## How to Use
### Prerequisites
- **PostgreSQL**: Ensure a PostgreSQL server is set up and accessible.
- **R Environment**: Install R and required libraries (`RPostgres`, `DBI`, `PerformanceAnalytics`, etc.).

### Steps to Run
1. **Database Setup**:
   - Restore the database using `backup.sql` from the `data` folder.
   - Alternatively, initialize the schema using `database.sql` in the `scripts` folder.

2. **R Analysis**:
   - Open `analysis.R` in RStudio or any R environment.
   - Configure the database connection details in the script.
   - Run the script to perform portfolio analysis and optimization.

3. **Documentation**:
   - Refer to the `Project-Report.pdf` file in the `docs` folder for in-depth project details and results.

## Future Enhancements
- Implement dynamic rebalancing of portfolio weights.
- Include alternative risk factors in the optimization model.
- Explore machine learning techniques for predictive portfolio optimization.
