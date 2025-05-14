# Stock Market Case in R
rm(list=ls(all=T)) # this just removes everything from memory


# Load CSV Files ----------------------------------------------------------
# Load daily prices from CSV - no parameters needed
dp<-read.csv('./filetransfer/daily_prices_2016_2021.csv') # no arguments

#Explore
head(dp) #first few rows
tail(dp) #last few rows
nrow(dp) #row count
ncol(dp) #column count

#remove the last row (because it was empty/errors)
dp<-head(dp,-1)
rm(dp) # remove from memory

# Connect to PostgreSQL ---------------------------------------------------

require(RPostgres) # did you install this package?
#require(DBI)
conn <- dbConnect(RPostgres::Postgres()
                 ,user="stockmarketreader"
                 ,password="read123"
                 ,host="postgres"
                 ,port=5432
                 ,dbname="stockmarket"
)

#custom calendar
qry<-'SELECT * FROM custom_calendar ORDER by date'
ccal<-dbGetQuery(conn,qry)
#eod prices and indices
# eod prices and indices (updated date range to include 2021-03-26)
qry1 <- "SELECT symbol, date, adj_close FROM eod_indices WHERE date BETWEEN '2015-12-31' AND '2021-03-26'"
qry2 <- "SELECT ticker AS symbol, date, adj_close FROM eod_quotes WHERE date BETWEEN '2015-12-31' AND '2021-03-26'"
eod <- dbGetQuery(conn, paste(qry1, 'UNION', qry2))
dbDisconnect(conn)
rm(conn)


#Explore
head(ccal)
tail(ccal)
nrow(ccal)

head(eod)
tail(eod)
nrow(eod)

head(eod[which(eod$symbol=='SP500TR'),])

# Use Calendar --------------------------------------------------------

tdays<-ccal[which(ccal$trading==1),,drop=F]
head(tdays)
nrow(tdays)-1 #trading days between 2015 and 2020

# Completeness ----------------------------------------------------------
# Percentage of completeness
pct<-table(eod$symbol)/(nrow(tdays)-1)
selected_symbols_daily<-names(pct)[which(pct>=0.99)]
eod_complete<-eod[which(eod$symbol %in% selected_symbols_daily),,drop=F]

#check
head(eod_complete)
tail(eod_complete)
nrow(eod_complete)

#Create eom and eom_complete
# Transform (Pivot) -------------------------------------------------------

require(reshape2) #did you install this package?
eod_pvt<-dcast(eod_complete, date ~ symbol,value.var='adj_close',fun.aggregate = mean, fill=NULL)
#check
eod_pvt[1:10,1:5] #first 10 rows and first 5 columns 
ncol(eod_pvt) # column count
nrow(eod_pvt)

# Merge with Calendar -----------------------------------------------------
eod_pvt_complete<-merge.data.frame(x=tdays[,'date',drop=F],y=eod_pvt,by='date',all.x=T)

#check
eod_pvt_complete[1:10,1:5] #first 10 rows and first 5 columns 
ncol(eod_pvt_complete)
nrow(eod_pvt_complete)

#use dates as row names and remove the date column
rownames(eod_pvt_complete)<-eod_pvt_complete$date
eod_pvt_complete$date<-NULL #remove the "date" column

#re-check
eod_pvt_complete[1:10,1:5] #first 10 rows and first 5 columns 
ncol(eod_pvt_complete)
nrow(eod_pvt_complete)

# Missing Data Imputation -----------------------------------------------------
# We can replace a few missing (NA or NaN) data items with previous data
# Let's say no more than 3 in a row...
require(zoo)
eod_pvt_complete<-na.locf(eod_pvt_complete,na.rm=F,fromLast=F,maxgap=3)

#re-check
eod_pvt_complete[1:10,1:5] #first 10 rows and first 5 columns 
ncol(eod_pvt_complete)
nrow(eod_pvt_complete)

# Calculating Returns -----------------------------------------------------
require(PerformanceAnalytics)
eod_ret<-CalculateReturns(eod_pvt_complete)

#check
eod_ret[1:10,1:3] #first 10 rows and first 3 columns 
ncol(eod_ret)
nrow(eod_ret)

#remove the first row
eod_ret<-tail(eod_ret,-1) #use tail with a negative value
#check
eod_ret[1:10,1:3] #first 10 rows and first 3 columns 
ncol(eod_ret)
nrow(eod_ret)

# Check for extreme returns -------------------------------------------
# There is colSums, colMeans but no colMax so we need to create it
colMax <- function(data) sapply(data, max, na.rm = TRUE)
# Apply it
max_daily_ret<-colMax(eod_ret)
max_daily_ret[1:10] #first 10 max returns
# And proceed just like we did with percentage (completeness)
selected_symbols_daily<-names(max_daily_ret)[which(max_daily_ret<=1.00)]
length(selected_symbols_daily)

#subset eod_ret
eod_ret<-eod_ret[,which(colnames(eod_ret) %in% selected_symbols_daily),drop=F]
#check
eod_ret[1:10,1:3] #first 10 rows and first 3 columns 

ncol(eod_ret)
nrow(eod_ret)


# Export data from R to CSV -----------------------------------------------
write.csv(eod_ret,'./filetransfer/eod_ret.csv')


# Tabular Return Data Analytics -------------------------------------------

my_tickers <- c('LYV','KUBTY','RDY','IMKTA','SFBS','MWA','NWBI','DOC','DLR','CIZN','GS','MASI','NFG','UPLD','MYRG','SP500TR')
eod_ret <- eod_ret[, my_tickers]

# We need to convert data frames to xts (extensible time series)
Ra <- as.xts(eod_ret[, my_tickers[my_tickers != "SP500TR",drop=F]])  # portfolio assets
Rb <- as.xts(eod_ret[, "SP500TR",drop=F]) 

head(Ra)
head(Rb)
tail(Ra)

# Stats
table.Stats(Ra)


# Distributions
table.Distributions(Ra)

# Returns
table.AnnualizedReturns(cbind(Rb,Ra),scale=252) # note for monthly use scale=12

# Accumulate Returns
acc_Ra<-Return.cumulative(Ra);acc_Ra
acc_Rb<-Return.cumulative(Rb);acc_Rb

# Capital Assets Pricing Model
table.CAPM(Ra,Rb)


# Graphical Return Data Analytics -----------------------------------------

# Cumulative returns chart
chart.CumReturns(Ra,legend.loc = 'topleft')
chart.CumReturns(Rb,legend.loc = 'topleft')


#Box plots
chart.Boxplot(cbind(Rb,Ra))
chart.Drawdown(Ra,legend.loc = 'bottomleft')

# MV Portfolio Optimization -----------------------------------------------

# withhold the last 58 trading days
Ra_training<-head(Ra,-58)
Rb_training<-head(Rb,-58)

# Cummulative returns for Range 1
acc_Ra_training<-Return.cumulative(Ra_training);acc_Ra_training
chart.CumReturns(Ra_training,legend.loc = 'topleft')

# use the last 58 trading days for testing
Ra_testing<-tail(Ra,58)
Rb_testing<-tail(Rb,58)

#optimize the MV (Markowitz 1950s) portfolio weights based on training
table.AnnualizedReturns(Rb_training)
mar<-mean(Rb_training) #we need daily minimum acceptable return
print(mar)
require(PortfolioAnalytics)
require(ROI) # make sure to install it
require(ROI.plugin.quadprog)  # make sure to install it
pspec<-portfolio.spec(assets=colnames(Ra_training))
pspec<-add.objective(portfolio=pspec,type="risk",name='StdDev')
pspec<-add.constraint(portfolio=pspec,type="full_investment")
pspec<-add.constraint(portfolio=pspec,type="return",return_target=mar)

#optimize portfolio
opt_p<-optimize.portfolio(R=Ra_training,portfolio=pspec,optimize_method = 'ROI')

#extract weights (negative weights means shorting)
opt_w<-opt_p$weights

# Weights for Range 1 (2016-2020)
round(opt_w, 4)

# Sum of weights for Range 1 (2016-2020)
sum(round(opt_w, 4))

#apply weights to test returns
Rp<-Rb_testing # easier to apply the existing structure
#define new column that is the dot product of the two vectors
Rp$ptf<-Ra_testing %*% opt_w

#check
head(Rp)
tail(Rp)

#Compare basic metrics
table.AnnualizedReturns(Rp)

# Chart Hypothetical Portfolio Returns ------------------------------------

chart.CumReturns(Rp,legend.loc = 'bottomright')

