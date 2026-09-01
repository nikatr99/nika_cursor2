
# ---- Load Libraries ----
library(shiny)
library(shinyjs)  # For JavaScript interactivity
library(shinydashboard)
library(googlesheets4)
library(ggplot2)
library(dplyr)
library(bslib)
library(shinydashboard)
library(tidyr)
library(plotly)
library(lubridate)
library(tidyverse)


# ---- Authentication and Google Sheets Setup ----
gs4_auth()
sheet_url <-"https://docs.google.com/spreadsheets/d/1gJQF1eWQ0CikBAElPU9cGvnbHG5M7r9YhloI9bvoe6s"


# Pull data from Google Sheets and transpose as necessary
dates <- read_sheet(sheet_url, range = "B1:AD1", col_names = FALSE) %>% 
  t() %>% 
  as.vector() %>% 
  as.Date(format = "%Y-%m-%d")  # adjust format if needed


# ---- Pull Revenue Data ----
# Pull revenue data
dtc_revenue <- read_sheet(sheet_url, range = "B8:AD8", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
dtc_hardware <- read_sheet(sheet_url, range = "B9:AD9", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
dtc_addons <- read_sheet(sheet_url, range = "B10:AD10", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
dtc_merch <- read_sheet(sheet_url, range = "B11:AD11", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
dtc_seeds <- read_sheet(sheet_url, range = "B12:AD12", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
dtc_taxes <- read_sheet(sheet_url, range = "B13:AD13", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
dtc_shipping <- read_sheet(sheet_url, range = "B14:AD14", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()

amazon_revenue <- read_sheet(sheet_url, range = "B15:AD15", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
amazon_hardware <- read_sheet(sheet_url, range = "B16:AD16", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
amazon_addons <- read_sheet(sheet_url, range = "B17:AD17", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
amazon_tax <- read_sheet(sheet_url, range = "B18:AD18", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
amazon_shipping <- read_sheet(sheet_url, range = "B19:AD19", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
amazon_giftwrap <- read_sheet(sheet_url, range = "B20:AD20", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()

digital_marketplaces_revenue <- read_sheet(sheet_url, range = "B21:AD21", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
rachio_revenue <- read_sheet(sheet_url, range = "B22:AD22", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
weatherflow_revenue <- read_sheet(sheet_url, range = "B26:AD26", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()

total_revenue <- read_sheet(sheet_url, range = "B30:AD30", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()

B2B_revenue <- read_sheet(sheet_url, range = "B41:AD41", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
bestbuy_revenue <- read_sheet(sheet_url, range = "B33:AD33", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
target_revenue <- read_sheet(sheet_url, range = "B37:AD37", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()

app_revenue <- read_sheet(sheet_url, range = "B48:AD48", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
google_store <- read_sheet(sheet_url, range = "B44:AD44", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
apple_store <- read_sheet(sheet_url, range = "B45:AD45", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
app_comission <- read_sheet(sheet_url, range = "B46:AD46", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
app_tax <- read_sheet(sheet_url, range = "B47:AD47", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()

# ---- Pull Orders Data ----

dtc_orders <- read_sheet(sheet_url, range = "B51:AD51", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
dtc_hardware_units <- read_sheet(sheet_url, range = "B52:AD52", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
dtc_addons_units <- read_sheet(sheet_url, range = "B53:AD53", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
dtc_merch_units <- read_sheet(sheet_url, range = "B54:AD54", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
dtc_seeds_units <- read_sheet(sheet_url, range = "B55:AD55", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()


amazon_orders <- read_sheet(sheet_url, range = "B56:AD56", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
amazon_hardware_units <- read_sheet(sheet_url, range = "B57:AD57", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
amazon_addons_units <- read_sheet(sheet_url, range = "B58:AD58", col_names = FALSE) %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()


digital_marketplaces_orders <- read_sheet(sheet_url, range = "B59:AD59", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
rachio_orders <- read_sheet(sheet_url, range = "B60:AD60", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
weatherflow_orders <- read_sheet(sheet_url, range = "B61:AD61", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()

total_orders <- read_sheet(sheet_url, range = "B62:AD62", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()

B2B_orders <- read_sheet(sheet_url, range = "B67:AD67", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
bestbuy_orders <- read_sheet(sheet_url, range = "B65:AD65", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
target_orders <- read_sheet(sheet_url, range = "B66:AD66", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()

app_orders <- read_sheet(sheet_url, range = "B72:AD72", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
google_store_orders <- read_sheet(sheet_url, range = "B70:AD70", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()
apple_store_orders <- read_sheet(sheet_url, range = "B71:AD71", col_names = FALSE)  %>% 
  t() %>%  # Transpose to get a single row of dates
  as.vector()



# ---- Pull Spend Data ----
# Pull spend data
meta_spend <- read_sheet(sheet_url, range = "B75:AD75", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

google_spend <- read_sheet(sheet_url, range = "B76:AD76", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

bing_spend <- read_sheet(sheet_url, range = "B77:AD77", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

tiktok_spend <- read_sheet(sheet_url, range = "B78:AD78", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

amazon_spend <- read_sheet(sheet_url, range = "B79:AD79", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

nextdoor_spend <- read_sheet(sheet_url, range = "B80:AD80", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

indiegogo_spend <- read_sheet(sheet_url, range = "B81:AD81", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

affiliate_fees <- read_sheet(sheet_url, range = "B82:AD82", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

rachio_fees <- read_sheet(sheet_url, range = "B83:AD83", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

weatherflow_fees <- read_sheet(sheet_url, range = "B84:AD84", col_names = FALSE) %>%
  t() %>%
  as.vector()

total_dtc_spend <- read_sheet(sheet_url, range = "B85:AD85", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

total_spend <- read_sheet(sheet_url, range = "B86:AD86", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

app_spend_meta <- read_sheet(sheet_url, range = "B89:AD89", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

app_spend_apple <- read_sheet(sheet_url, range = "B90:AD90", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

app_spend_google <- read_sheet(sheet_url, range = "B91:AD91", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

total_app_spend <- read_sheet(sheet_url, range = "B92:AD92", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

# ---- Pull Data for Metrics Shown in the Image ----
# Pull Blended ROAS and its breakdown
blended_roas <- read_sheet(sheet_url, range = "B94:AD94", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

wroas <- read_sheet(sheet_url, range = "B95:AD95", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

aroas <- read_sheet(sheet_url, range = "B96:AD96", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

approas <- read_sheet(sheet_url, range = "B97:AD97", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

# Pull Blended SPU and its breakdown
blended_SPU <- read_sheet(sheet_url, range = "B99:AD99", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

wSPU <- read_sheet(sheet_url, range = "B100:AD100", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

aSPU <- read_sheet(sheet_url, range = "B101:AD101", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

appSPU <- read_sheet(sheet_url, range = "B102:AD102", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

# Pull Web CR, AOV, and related metrics
web_cr <- read_sheet(sheet_url, range = "B104:AD104", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

web_aov <- read_sheet(sheet_url, range = "B105:AD105", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

faov <- read_sheet(sheet_url, range = "B106:AD106", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

raov <- read_sheet(sheet_url, range = "B107:AD107", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

# Pull Customers and their types
returning_customers <- read_sheet(sheet_url, range = "B110:AD110", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

first_time_customers <- read_sheet(sheet_url, range = "B111:AD111", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()


# Function to ensure vector length matches dates
ensure_length <- function(vec, length_out) {
  if (length(vec) < length_out) {
    c(vec, rep(NA, length_out - length(vec)))
  } else {
    vec
  }
}

# Ensure all spend vectors match the length of dates
meta_spend <- ensure_length(meta_spend, length(dates))
google_spend <- ensure_length(google_spend, length(dates))
bing_spend <- ensure_length(bing_spend, length(dates))
tiktok_spend <- ensure_length(tiktok_spend, length(dates))
amazon_spend <- ensure_length(amazon_spend, length(dates))
nextdoor_spend <- ensure_length(nextdoor_spend, length(dates))
indiegogo_spend <- ensure_length(indiegogo_spend, length(dates))
affiliate_fees <- ensure_length(affiliate_fees, length(dates))
rachio_fees <- ensure_length(rachio_fees, length(dates))
weatherflow_fees <- ensure_length(weatherflow_fees, length(dates))
total_dtc_spend <- ensure_length(total_dtc_spend, length(dates))
total_spend <- ensure_length(total_spend, length(dates))
app_spend_meta <- ensure_length(app_spend_meta, length(dates))
app_spend_apple <- ensure_length(app_spend_apple, length(dates))
app_spend_google <- ensure_length(app_spend_google, length(dates))
total_app_spend <- ensure_length(total_app_spend, length(dates))


# Combine into a dataframe
revenue_data <- data.frame(
  Date = dates,
  DTC_Revenue = as.numeric(dtc_revenue),
  DTC_Hardware = as.numeric(dtc_hardware),
  DTC_Addons = as.numeric(dtc_addons),
  DTC_Merch = as.numeric(dtc_merch),
  DTC_Seeds = as.numeric(dtc_seeds),
  DTC_Taxes = as.numeric(dtc_taxes),
  DTC_Shipping = as.numeric(dtc_shipping),
  
  Amazon_Revenue = as.numeric(amazon_revenue),
  Amazon_Hardware = as.numeric(amazon_hardware),
  Amazon_Addons = as.numeric(amazon_addons),
  Amazon_Tax = as.numeric(amazon_tax),
  Amazon_Shipping = as.numeric(amazon_shipping),
  Amazon_GiftWrap = as.numeric(amazon_giftwrap),
  
  Rachio_Revenue = as.numeric(rachio_revenue),
  Weatherflow_Revenue = as.numeric(weatherflow_revenue),
  Digital_Marketplaces_Revenue = as.numeric(digital_marketplaces_revenue),
  Total_Revenue = as.numeric(total_revenue),
  B2B_Revenue = as.numeric(B2B_revenue),
  BestBuy_Revenue = as.numeric(bestbuy_revenue),
  Target_Revenue = as.numeric(target_revenue),
  App_Revenue = as.numeric(app_revenue),
  Google_Store = as.numeric(google_store),
  Apple_Store = as.numeric(apple_store),
  App_Comission = as.numeric(app_comission),
  App_Tax = as.numeric(app_tax),
  
  # Orders
  DTC_Orders = as.numeric(dtc_orders),
  DTC_Hardware_Units = as.numeric(dtc_hardware_units),
  DTC_Addons_Units = as.numeric(dtc_addons_units),
  DTC_Merch_Units = as.numeric(dtc_merch_units),
  DTC_Seeds_Units = as.numeric(dtc_seeds_units),
  Amazon_Orders = as.numeric(amazon_orders),
  Amazon_Hardware_Units = as.numeric(amazon_hardware_units),
  Amazon_Addons_Units = as.numeric(amazon_addons_units),
  Digital_Marketplaces_Orders = as.numeric(digital_marketplaces_orders),
  Rachio_Orders = as.numeric(rachio_orders),
  Weatherflow_Orders = as.numeric(weatherflow_orders),
  Total_Orders = as.numeric(total_orders),
  B2B_Orders = as.numeric(B2B_orders),
  BestBuy_Orders = as.numeric(bestbuy_orders),
  Target_Orders = as.numeric(target_orders),
  App_Orders = as.numeric(app_orders),
  Google_Store_Orders = as.numeric(google_store_orders),
  Apple_Store_Orders = as.numeric(apple_store_orders),
  
  Meta_Spend = as.numeric(meta_spend),
  Google_Spend = as.numeric(google_spend),
  Bing_Spend = as.numeric(bing_spend),
  TikTok_Spend = as.numeric(tiktok_spend),
  Amazon_Spend = as.numeric(amazon_spend),
  Nextdoor_Spend = as.numeric(nextdoor_spend),
  IndieGoGo_Spend = as.numeric(indiegogo_spend),
  Affiliate_Fees = as.numeric(affiliate_fees),
  Rachio_Fees = as.numeric(rachio_fees),
  Weatherflow_Fees = as.numeric(weatherflow_fees),
  Fees = as.numeric(rachio_fees) + as.numeric(weatherflow_fees),
  Total_DTC_Spend = as.numeric(total_dtc_spend),
  Total_Spend = as.numeric(total_spend),
  App_Spend_Meta = as.numeric(app_spend_meta),
  App_Spend_Apple = as.numeric(app_spend_apple),
  App_Spend_Google = as.numeric(app_spend_google),
  Total_App_Spend = as.numeric(total_app_spend),
  Blended_ROAS = as.numeric(blended_roas),
  wROAS = as.numeric(wroas),
  aROAS = as.numeric(aroas),
  appROAS = as.numeric(approas),
  
  Blended_SPU = as.numeric(blended_SPU),
  wSPU = as.numeric(wSPU),
  aSPU = as.numeric(aSPU),
  appSPU = as.numeric(appSPU),
  
  Web_CR = as.numeric(web_cr),
  Web_AOV = as.numeric(web_aov),
  fAOV = as.numeric(faov),
  rAOV = as.numeric(raov),
  Returning_Customers = as.numeric(returning_customers),
  First_Time_Customers = as.numeric(first_time_customers)
  
)

dtc_data <- read_sheet(sheet_url, sheet = "DTC - P&L")

dtc_subset = dtc_data[c(53:56, 59:60, 63:72, 75:82), ]

# 2. Set row names to SKU names
rownames(dtc_subset) <- dtc_subset[[1]]
dtc_subset_names = dtc_subset

# 3. Drop the SKU name column
dtc_subset <- dtc_subset[, -1]

dtc_transposed <- as.data.frame(t(dtc_subset), stringsAsFactors = FALSE)

# Ensure all columns are numeric
dtc_transposed[] <- lapply(dtc_transposed, function(x) as.numeric(as.character(x)))


# 5. Rename columns to add 'dtc_' prefix
colnames(dtc_transposed) <- paste0("dtc_", dtc_subset_names[[1]])

dtc_transposed <- dtc_transposed[-nrow(dtc_transposed), ]
rownames(dtc_transposed) <- NULL


# 6. Bind to existing revenue_data
revenue_data <- cbind(revenue_data, dtc_transposed)

# ---- amazon data ----
amazon_data <- read_sheet(sheet_url, sheet = "AMAZON - P&L")

amazon_subset = amazon_data[c(27:30, 33:40), ]

# 2. Set row names to SKU names
rownames(amazon_subset) <- amazon_subset[[1]]
amazon_subset_names = amazon_subset

# 3. Drop the SKU name column
amazon_subset <- amazon_subset[, -1]

amazon_transposed <- as.data.frame(t(amazon_subset), stringsAsFactors = FALSE)

# Ensure all columns are numeric
amazon_transposed[] <- lapply(amazon_transposed, function(x) as.numeric(as.character(x)))


# 5. Rename columns to add 'dtc_' prefix
colnames(amazon_transposed) <- paste0("amazon_", amazon_subset_names[[1]])

amazon_transposed <- amazon_transposed[-nrow(amazon_transposed), ]
rownames(amazon_transposed) <- NULL


# 6. Bind to existing revenue_data
revenue_data <- cbind(revenue_data, amazon_transposed)

saveRDS(revenue_data, file = "revenue_data.rds")

# ---- rachio data ----
rachio_data <- read_sheet(sheet_url, sheet = "Digital Marketplaces - P&L")

rachio_subset = rachio_data[c(12:15), ]

# 2. Set row names to SKU names
rownames(rachio_subset) <- rachio_subset[[1]]
rachio_subset_names = rachio_subset

# 3. Drop the SKU name column
rachio_subset <- rachio_subset[, -1]

rachio_transposed <- as.data.frame(t(rachio_subset), stringsAsFactors = FALSE)

# Ensure all columns are numeric
rachio_transposed[] <- lapply(rachio_transposed, function(x) as.numeric(as.character(x)))


# 5. Rename columns to add 'dtc_' prefix
colnames(rachio_transposed) <- paste0("rachio_", rachio_subset_names[[1]])

rachio_transposed <- rachio_transposed[-nrow(rachio_transposed), ]
rownames(rachio_transposed) <- NULL


# 6. Bind to existing revenue_data
revenue_data <- cbind(revenue_data, rachio_transposed)

saveRDS(revenue_data, file = "revenue_data.rds")

# ---- weatherflow data ----

weatherflow_subset = rachio_data[c(124:127), ]

# 2. Set row names to SKU names
rownames(weatherflow_subset) <- weatherflow_subset[[1]]
weatherflow_subset_names = weatherflow_subset

# 3. Drop the SKU name column
weatherflow_subset <- weatherflow_subset[, -1]

weatherflow_transposed <- as.data.frame(t(weatherflow_subset), stringsAsFactors = FALSE)

# Ensure all columns are numeric
weatherflow_transposed[] <- lapply(weatherflow_transposed, function(x) as.numeric(as.character(x)))


# 5. Rename columns to add 'dtc_' prefix
colnames(weatherflow_transposed) <- paste0("weatherflow_", weatherflow_subset_names[[1]])

weatherflow_transposed <- weatherflow_transposed[-nrow(weatherflow_transposed), ]
rownames(weatherflow_transposed) <- NULL


# 6. Bind to existing revenue_data
revenue_data <- cbind(revenue_data, weatherflow_transposed)



campaign_notes_df <- data.frame(
  note = c(
    "Valentines Day Sale: 33% off 2nd feeder",
    "Flash Sale: 30% off (MAP Price Model)",
    "A/B Testing - Seeds #1 (First bag free & $26.90 Price)",
    "HBF Pre-Launch (PRO)",
    "Women's Day Offer: 30% off (MAP Price Model)",
    "HBF Main Launch"
  ),
  start = as.Date(c("2024-02-05", "2024-02-15","2024-02-22","2024-02-28", "2024-02-29", "2024-02-29")),
  end = as.Date(c("2024-02-14", "2024-02-27","2024-02-29","2024-02-28", "2024-02-29", "2024-02-29")),
  stringsAsFactors = FALSE
)

# 1. Read the Post-purchase survey sheet
pps_data <- read_sheet(sheet_url, sheet = "PP - Data")

# 2. Create a base dataset with date column
survey_data <- data.frame(Date = dates)

# 3. Subset only relevant rows (based on your survey questions)
pps_subset <- pps_data[c(1:8, 22:24, 35, 41, 47, 53), ]

# 4. Store the original row names (question labels) separately
question_labels <- as.character(pps_subset[[1]])

# 5. Set row names and drop first column
rownames(pps_subset) <- question_labels
pps_subset <- pps_subset[, -1]

# 6. Transpose and convert to numeric
pps_transposed <- as.data.frame(t(pps_subset), stringsAsFactors = FALSE)
pps_transposed[] <- lapply(pps_transposed, function(x) as.numeric(as.character(x)))

# 7. Rename columns with appropriate prefixes
colnames(pps_transposed)[1:8]   <- paste0("q1_", question_labels[1:8])
colnames(pps_transposed)[9:11]  <- paste0("q2_", question_labels[9:11])
colnames(pps_transposed)[12:15] <- paste0("q3_", question_labels[12:15])

# 8. Clean up trailing summary rows (if needed)
pps_transposed <- pps_transposed[-((nrow(pps_transposed)-3):nrow(pps_transposed)), ]
rownames(pps_transposed) <- NULL

# 9. Combine with your base date table
survey_data <- cbind(survey_data, pps_transposed)

saveRDS(campaign_notes_df, file = "campaign_notes_df.rds")
saveRDS(revenue_data, file = "revenue_data.rds")
saveRDS(survey_data, file = "survey_data.rds")

