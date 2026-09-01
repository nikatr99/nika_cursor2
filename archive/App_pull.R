
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
sheet_url <-"https://docs.google.com/spreadsheets/d/1HxpB94WsfrgbdXBN4EHYhb7JKVomYo7mTSzIH6Jtvy0/edit"


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

# Pull Blended CAC and its breakdown
blended_cac <- read_sheet(sheet_url, range = "B99:AD99", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

wcac <- read_sheet(sheet_url, range = "B100:AD100", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

acac <- read_sheet(sheet_url, range = "B101:AD101", col_names = FALSE) %>%
  t() %>%  # Transpose to get a single row
  as.vector()

appcac <- read_sheet(sheet_url, range = "B102:AD102", col_names = FALSE) %>%
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
  
  Blended_CAC = as.numeric(blended_cac),
  wCAC = as.numeric(wcac),
  aCAC = as.numeric(acac),
  appCAC = as.numeric(appcac),
  
  Web_CR = as.numeric(web_cr),
  Web_AOV = as.numeric(web_aov),
  fAOV = as.numeric(faov),
  rAOV = as.numeric(raov),
  Returning_Customers = as.numeric(returning_customers),
  First_Time_Customers = as.numeric(first_time_customers)
  
)

dtc_data <- read_sheet(sheet_url, sheet = "DTC - P&L")

dtc_subset = dtc_data[c(52:55, 58:59, 62:71, 74:81), ]

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


# ---- UI Definition ----
# UI Definition

ui <- dashboardPage(
  dashboardHeader(disable = TRUE),
  dashboardSidebar(
    width = 200, # Sidebar width
    tags$style(HTML("
      .skin-blue .main-sidebar {
        background-color: #f5f5f5 !important; /* Light gray background for sidebar */
        border-right: 1px solid #ddd;
      }
      .skin-blue .sidebar-menu > li > a {
        color: #333 !important; /* Black text for menu items */
        font-family: 'Montserrat', sans-serif;
        font-weight: bold;
        font-size: 14px;
      }
      .skin-blue .sidebar-menu > li.active > a {
        background-color: #e0e0e0 !important; /* Highlight for active menu item */
        color: #333 !important;
      }
      .skin-blue .sidebar-menu > li > a:hover {
        background-color: #e0e0e0 !important;
        color: #333 !important;
      }
    ")),
    sidebarMenu(
      id = "tabs",  # <-- THIS IS THE FIX
      menuItem("Summary", tabName = "summary", icon = icon("chart-line")),
      menuItem("Visualization", tabName = "visualization", icon = icon("chart-bar"))
    ),
    
    tags$style(HTML("
      .sidebar {
        background-color: #ffffff !important; /* White background for sidebar */
      }
      .sidebar .sidebar-menu a {
        color: black !important; /* Black text for menu items */
        font-family: 'Montserrat', sans-serif;
        font-weight: bold;
      }
    "))
  ),
  dashboardBody(
    useShinyjs(),  # For interactive stuff
    tags$head(
      tags$link(
        href = "https://fonts.googleapis.com/css2?family=Montserrat:wght@400;700&display=swap", 
        rel = "stylesheet"
      )
    ),
    
    # Global Date Range Input (persistent across tabs)
    div(
      class = "date-select-container",
      style = "display: flex; justify-content: flex-end; padding: 15px;",
      dateRangeInput(
        inputId = "selected_date_range",
        label = "Select Date Range:",
        start = min(revenue_data$Date, na.rm = TRUE),
        end = max(revenue_data$Date, na.rm = TRUE),
        min = min(revenue_data$Date, na.rm = TRUE),
        max = max(revenue_data$Date, na.rm = TRUE),
        format = "yyyy-mm-dd",
        weekstart = 1
      )
    ),
    
    # Wrap the tabs
    tabItems(
      
      # ---- Summary Tab ----
      tabItem(tabName = "summary",
              
              tags$style(HTML("
          body {
            font-family: 'Montserrat', sans-serif;
          }
          .date-select-container label {
            font-family: 'Montserrat', sans-serif;
            font-weight: bold;
            font-size: 18px;
            color: #333;
          }
        
          .form-control {
            font-family: 'Montserrat', sans-serif;
            font-size: 16px;
            padding: 10px 12px;
            border-radius: 10px;
            border: 1px solid #ccc;
          }
        
          .form-control:focus {
            border-color: #2ecc71;
            box-shadow: 0 0 5px rgba(46, 204, 113, 0.5);
          }
          .total-revenue-container {
            background-color: #2ecc71;
            padding: 20px;
            border-radius: 15px;
            text-align: center;
            color: white;
            margin-bottom: 40px;
          }
          .total-spend-container {
            background-color: #A52A2A;
            padding: 20px;
            border-radius: 15px;
            text-align: center;
            color: white;
            margin-top: 40px;
            margin-bottom: 40px;
          }
          .revenue-label {
            font-size: 18px;
            font-weight: bold;
            display: inline;
          }
          .percentage-change {
            font-size: 12px;
            color: #ffffff;
            font-weight: normal;
            margin-left: 10px;
          }
          .positive-change {
            color: #2ecc71;
          }
          .negative-change {
            color: #e74c3c;
          }
          .revenue-value-white {
            font-size: 40px;
            font-weight: bold;
            color: white;
          }
          .revenue-value-brown {
            font-size: 40px;
            font-weight: bold;
            color: white;
          }
          .revenue-item-container {
            display: flex;
            justify-content: space-between;
            margin-bottom: 40px;
          }
          .revenue-item {
            text-align: center;
            flex: 1;
          }
          .revenue-sub-label {
            font-size: 14px;
            font-weight: bold;
            color: #333333;
          }
          .revenue-value-green {
            font-size: 24px;
            color: #2ecc71;
            font-weight: 400;
          }
          .revenue-value-red {
            font-size: 24px;
            color: #A52A2A;
            font-weight: 400;
          }
          .small-revenue-value {
            font-size: 30px;
            color: black;
            font-weight: normal;
          }
          .green-title {
            color: #2ecc71;
            font-size: 18px;
            font-weight: bold;
          }
          .red-title {
            color: #A52A2A;
            font-size: 18px;
            font-weight: bold;
          }
          .revenue-label-with-tooltip {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
          }
          
          .tooltip-container {
            position: relative;
            display: inline-block;
          }
          
          .info-circle {
            width: 20px;
            height: 20px;
            background-color: white;
            color: #2ecc71;
            font-weight: bold;
            font-family: 'Montserrat', sans-serif;
            font-size: 14px;
            text-align: center;
            line-height: 20px;
            border-radius: 50%;
            cursor: pointer;
            box-shadow: 0 0 5px rgba(0,0,0,0.15);
          }
          
          .tooltip-text {
            visibility: hidden;
            background-color: white;
            color: #333;
            font-family: 'Montserrat', sans-serif;
            font-size: 13px;
            font-weight: normal;
            text-align: center;
            border-radius: 10px;
            padding: 10px;
            position: absolute;
            z-index: 100;
            bottom: 125%; /* Show above the icon */
            left: 50%;
            transform: translateX(-50%);
            width: 260px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
            opacity: 0;
            transition: opacity 0.3s ease;
          }
          
          .tooltip-container:hover .tooltip-text {
            visibility: visible;
            opacity: 1;
          }
          .info-circle-red {
            color: #A52A2A; /* white icon color inside */
            background-color: #ffffff; /* white background to match revenue icon */
            box-shadow: 0 0 5px rgba(0,0,0,0.15); /* same as green one */
          }




        ")),
              
              div(class = "total-revenue-container",
                  div(
                    class = "revenue-label-with-tooltip",
                    HTML('
                      <span class="revenue-label">Total Revenue</span>
                      <div class="tooltip-container">
                        <div class="info-circle">i</div>
                        <div class="tooltip-text">Includes DTC Revenue, Amazon Revenue and Digital Marketplaces Revenue</div>
                      </div>
                    '),
                    span(textOutput("total_percentage_change"), class = "percentage-change")
                  ),
                  
                  div(textOutput("total_revenue_output"), class = "revenue-value-white")
              ),
              div(class = "revenue-item-container",
                  div(
                    div("DTC Revenue", class = "revenue-sub-label"),
                    div(tags$span(
                      textOutput("dtc_revenue_output"),
                      class = "revenue-value-green",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_dtc_revenue', Math.random())"),
                    class = "revenue-item",
                    uiOutput("dtc_revenue_details") # Placeholder for dynamic content
                  ),
                  div(
                    div("Amazon Revenue", class = "revenue-sub-label"),
                    div(tags$span(
                      textOutput("amazon_revenue_output"),
                      class = "revenue-value-green",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_amazon_revenue', Math.random())"),
                    class = "revenue-item",
                    uiOutput("amazon_revenue_details") # Placeholder for dynamic content
                  ),
                  div(
                    div("Digital Marketplaces", class = "revenue-sub-label"),
                    div(tags$span(
                      textOutput("digital_marketplaces_output"),
                      class = "revenue-value-green",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_digital_marketplaces', Math.random())"),
                    class = "revenue-item",
                    uiOutput("digital_marketplaces_details")
                  )
              ),
              div(class = "revenue-item-container",
                  div(
                    div("B2B Revenue", class = "green-title"),
                    div(tags$span(
                      textOutput("b2b_revenue_output"),
                      class = "small-revenue-value",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_b2b_revenue', Math.random())")
                  ),
                  div(
                    div("App Revenue", class = "green-title"),
                    div(tags$span(
                      textOutput("app_revenue_output"),
                      class = "small-revenue-value",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_app_revenue', Math.random())")
                  )
              ),
              # Place expandable boxes below this flex row
              div(
                style = "display: flex; justify-content: space-between;",
                uiOutput("b2b_revenue_details"),
                uiOutput("app_revenue_details")
              ),
              div(class = "total-spend-container",
                  div(
                    class = "revenue-label-with-tooltip",
                    HTML('
                        <span class="revenue-label">Total Spend</span>
                        <div class="tooltip-container">
                          <div class="info-circle info-circle-red">i</div>
                          <div class="tooltip-text">Includes DTC Spend, Amazon Spend, IndieGoGo Spend and Fees</div>
                        </div>
                      '),
                    span(textOutput("total_spend_percentage_change"), class = "percentage-change")
                  ),
                  
                  div(textOutput("total_spend_output"), class = "revenue-value-brown")
              ),
              div(class = "revenue-item-container",
                  div(
                    div("DTC Spend", class = "revenue-sub-label"),
                    div(tags$span(
                      textOutput("dtc_spend_output"),
                      class = "revenue-value-red",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_dtc_spend', Math.random())"),
                    class = "revenue-item",
                    uiOutput("dtc_spend_details")
                  ),
                  div(
                    div("Amazon Spend", class = "revenue-sub-label"),
                    div(textOutput("amazon_spend_output"), class = "revenue-value-red"),
                    class = "revenue-item"
                  ),
                  div(
                    div("IndieGoGo Spend", class = "revenue-sub-label"),
                    div(textOutput("indiegogo_spend_output"), class = "revenue-value-red"),
                    class = "revenue-item"
                  ),
                  div(
                    div("Fees", class = "revenue-sub-label"),
                    div(tags$span(
                      textOutput("fees_output"),
                      class = "revenue-value-red",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_fees', Math.random())"),
                    class = "revenue-item",
                    uiOutput("fees_details")
                  )
              ),
              div(class = "revenue-item-container",
                  div(
                    div("Total App Spend", class = "red-title"),
                    div(tags$span(
                      textOutput("total_app_spend_output"),
                      class = "small-revenue-value",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_app_spend', Math.random())"),
                    class = "revenue-item",
                    uiOutput("app_spend_details") # Placeholder for dynamic content
                  )
              ),
              # ---- UI: Adding Expandable Container for Blended ROAS ----
              # Dark grey container with 4 metrics
              div(class = "custom-container",
                  style = "background-color: #7b868c; padding: 20px; border-radius: 15px; text-align: center; color: white; margin-top: 40px;",
                  div(
                    style = "display: flex; justify-content: space-between; align-items: center;",
                    div(
                      style = "flex: 1; text-align: center; margin: 0 10px;",
                      div(
                        style = "cursor: pointer;",
                        strong("Blended ROAS:"),
                        div(
                          span(
                            textOutput("blended_roas_output"),
                            style = "font-size: 24px; font-weight: bold;",
                            onclick = "Shiny.onInputChange('toggle_blended_roas', Math.random())"
                          )
                        )
                      ),
                      uiOutput("blended_roas_details")  # <-- stays inside this column
                    ),
                    
                    div(
                      style = "flex: 1; text-align: center; margin: 0 10px;",
                      div(
                        style = "cursor: pointer;",
                        strong("Blended CAC:"),
                        div(
                          span(
                            textOutput("blended_cac_output"),
                            style = "font-size: 24px; font-weight: bold;",
                            onclick = "Shiny.onInputChange('toggle_blended_cac', Math.random())"
                          )
                        )
                      ),
                      uiOutput("blended_cac_details")  # ← The new expandable content
                    ),
                    
                    div(
                      style = "flex: 1; text-align: center; margin: 0 10px;",
                      strong("Web CR:"),
                      span(textOutput("web_cr_output"), style = "font-size: 24px; font-weight: bold;")
                    ),
                    div(
                      style = "flex: 1; text-align: center; margin: 0 10px;",
                      div(
                        style = "cursor: pointer;",
                        strong("Web AOV:"),
                        div(
                          span(
                            textOutput("web_aov_output"),
                            style = "font-size: 24px; font-weight: bold;",
                            onclick = "Shiny.onInputChange('toggle_web_aov', Math.random())"
                          )
                        )
                      ),
                      uiOutput("web_aov_details")  # ← new container rendered inside column
                    ),
                    div(
                      style = "flex: 1; text-align: center; margin: 0 10px;",
                      strong("Returning Customers:"),
                      div(textOutput("returning_customer_output"), style = "font-size: 24px; font-weight: bold;")
                    )
                    
                    
                  )
              ),
              # ---- UI: Orders Summary Section ----
              # ---- UI: Orders Summary Section ----
              div(
                style = "margin-top: 30px; padding: 20px; background-color: #f0f0f0; border-radius: 15px;",
                fluidRow(
                  style = "margin-bottom: 40px;",  # Add spacing after the first row
                  column(4, div(
                    style = "text-align: center;",
                    div(
                      style = "font-size: 42px; font-weight: normal; cursor: pointer;",
                      span(
                        textOutput("dtc_orders_output"),
                        onclick = "Shiny.onInputChange('toggle_dtc_orders', Math.random())"
                      )
                    ),
                    div(style = "font-size: 14px; font-weight: bold; color: #7b868c;", "DTC Orders"),
                    uiOutput("dtc_orders_details")  # 👈 this line shows the grey breakdown
                  )),
                  
                  column(4, div(
                    style = "text-align: center;",
                    div(
                      style = "font-size: 42px; font-weight: normal; cursor: pointer;",
                      span(
                        textOutput("amazon_orders_output"),
                        onclick = "Shiny.onInputChange('toggle_amazon_orders', Math.random())"
                      )
                    ),
                    div(style = "font-size: 14px; font-weight: bold; color: #7b868c;", "Amazon Orders"),
                    uiOutput("amazon_orders_details")  # 👈 attaches the grey box
                  )),
                  
                  column(4, div(
                    style = "text-align: center;",
                    div(
                      style = "font-size: 42px; font-weight: normal; cursor: pointer;",
                      span(
                        textOutput("digital_marketplaces_orders_output"),
                        onclick = "Shiny.onInputChange('toggle_digital_marketplaces_orders', Math.random())"
                      )
                    ),
                    div(style = "font-size: 14px; font-weight: bold; color: #7b868c;", "Digital Marketplaces Orders"),
                    uiOutput("digital_marketplaces_orders_details")  # 👈 attaches the expandable box
                  ))
                  
                ),
                fluidRow(
                  column(6, div(
                    style = "text-align: center;",
                    div(
                      style = "font-size: 42px; font-weight: normal; cursor: pointer;",
                      span(
                        textOutput("b2b_orders_output"),
                        onclick = "Shiny.onInputChange('toggle_b2b_orders', Math.random())"
                      )
                    ),
                    div(style = "font-size: 14px; font-weight: bold; color: #7b868c;", "B2B Orders"),
                    uiOutput("b2b_orders_details")
                  )),
                  
                  column(6, div(
                    style = "text-align: center;",
                    div(
                      style = "font-size: 42px; font-weight: normal; cursor: pointer;",
                      span(
                        textOutput("app_orders_output"),
                        onclick = "Shiny.onInputChange('toggle_app_orders', Math.random())"
                      )
                    ),
                    div(style = "font-size: 14px; font-weight: bold; color: #7b868c;", "App Orders"),
                    uiOutput("app_orders_details")
                  ))
                  
                )
              )
              
              
              
              
              
      ),
      # Blank Page
      tabItem(
        tabName = "visualization",
        # In tabItem(tabName = "visualization")
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            
            # Title on the left
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>
    <span style='color:#2ecc71;'>Revenue</span> vs 
    <span style='color:#A52A2A;'>Spend</span> Over Time
  </h2>"),
            
            # Dropdown on the right
            div(style = "display: flex; gap: 12px;",
                selectInput(
                  inputId = "selected_view_mode",
                  label = NULL,
                  choices = c("Absolute", "Relative"),
                  selected = "Absolute",
                  width = "150px"
                ),
                selectInput(
                  inputId = "selected_revenue_spend_type",
                  label = NULL,
                  choices = c("Total" = "Total", "DTC" = "DTC", "Amazon" = "Amazon", "App" = "App", "B2B" = "B2B"),
                  selected = "Total",
                  width = "200px"
                )
            )
            
          ),
          
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("revenue_vs_spend_plot", height = "500px")
          )
        ),
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          
          # ---- Title and Dropdown in Same Row ----
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            
            # Title on the left
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>
      <span style='color:#2ecc71;'>ROAS</span> per Day
    </h2>"),
            
            # Dropdown on the right
            selectInput(
              inputId = "selected_roas_type",
              label = NULL,
              choices = c("Blended ROAS" = "Blended_ROAS",
                          "DTC ROAS (wROAS)" = "wROAS",
                          "Amazon ROAS (aROAS)" = "aROAS",
                          "App ROAS (appROAS)" = "appROAS"),
              selected = "Blended_ROAS",
              width = "250px"
            )
          ),
          
          # ---- Chart Container ----
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("blended_roas_bar_chart", height = "500px")
          )
        ),
        
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          
          # ---- Title and Dropdown in Same Row ----
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            
            # Title on the left
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>
      <span style='color:#A52A2A;'>CAC</span> per Day
    </h2>"),
            
            # Dropdown on the right
            selectInput(
              inputId = "selected_cac_type",
              label = NULL,
              choices = c("Blended CAC" = "Blended_CAC",
                          "DTC CAC (wCAC)" = "wCAC",
                          "Amazon CAC (aCAC)" = "aCAC",
                          "App CAC (appCAC)" = "appCAC"),
              selected = "Blended_CAC",
              width = "250px"
            )
          ),
          
          # ---- Chart Container ----
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("blended_cac_bar_chart", height = "500px")
          )
        ),
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          
          # Title
          HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin-bottom: 20px;'>
    <span style='color:#7b868c;'>Conversion Rate</span> per Day
  </h2>"),
          
          # Chart container
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("cr_bar_chart", height = "500px")
          )
        ),
        
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          
          # --- Title + Dropdown ---
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>
      <span style='color:#3498db;'>AOV</span> per Day
    </h2>"),
            selectInput(
              inputId = "selected_aov_type",
              label = NULL,
              choices = c("Web AOV" = "Web_AOV", "Customer Segments AOV" = "Segmented_AOV"),
              
              selected = "Web_AOV",
              width = "300px"
            )
          ),
          
          # Chart container
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("aov_bar_chart", height = "500px")
          )
        ),
        
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          
          # Title
          HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin-bottom: 20px;'>
    <span style='color:#2ecc71;'>Returning</span> vs 
    <span style='color:#3498db;'>First-Time</span> Customers (%)
  </h2>"),
          
          # Chart container
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("customer_split_chart", height = "500px")
          )
        ),
        
        
        
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            
            # Title on the left
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>
    Revenue Composition Over Time
  </h2>"),
            
            # Dropdown on the right
            selectInput(
              inputId = "selected_revenue_view_mode",
              label = NULL,
              choices = c("Relative", "Absolute"),  # Default is relative
              selected = "Relative",
              width = "200px"
            )
          ),
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("revenue_share_chart", height = "500px")
          )
        ),
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          
          # --- Title + Dropdown in Flex Row ---
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            
            # Title on the left
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>
      Spend Composition Over Time
    </h2>"),
            
            # Dropdown on the right
            div(
              style = "display: flex; gap: 12px;",
              selectInput(
                inputId = "selected_spend_view_mode",
                label = NULL,
                choices = c("Relative", "Absolute"),
                selected = "Relative",
                width = "200px"
              ),
              selectInput(
                inputId = "selected_spend_composition",
                label = NULL,
                choices = c("Total Spend" = "Total", "DTC Spend" = "DTC"),
                selected = "Total",
                width = "250px"
              )
            )
            
          ),
          
          # Chart container
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("spend_composition_chart", height = "500px")
          )
        )
        
        
        
        
        
        
      )
      
      
    )
    
    
    
  )
)




# ---- Server Logic ----
# Define Server Logic
server <- function(input, output, session) {
  # Reactive value to track if the additional app spend details are visible
  app_spend_visible <- reactiveVal(FALSE)
  dtc_revenue_visible <- reactiveVal(FALSE)
  amazon_revenue_visible <- reactiveVal(FALSE)
  dtc_spend_visible <- reactiveVal(FALSE)
  fees_visible <- reactiveVal(FALSE)
  digital_marketplaces_visible <- reactiveVal(FALSE)
  b2b_visible <- reactiveVal(FALSE)
  app_revenue_visible <- reactiveVal(FALSE)
  dtc_orders_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_dtc_orders, {
    dtc_orders_visible(!dtc_orders_visible())
  })
  amazon_orders_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_amazon_orders, {
    amazon_orders_visible(!amazon_orders_visible())
  })
  
  digital_marketplaces_orders_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_digital_marketplaces_orders, {
    digital_marketplaces_orders_visible(!digital_marketplaces_orders_visible())
  })
  b2b_orders_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_b2b_orders, {
    b2b_orders_visible(!b2b_orders_visible())
  })
  app_orders_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_app_orders, {
    app_orders_visible(!app_orders_visible())
  })
  
  
  # Toggle visibility when the button is clicked
  observeEvent(input$toggle_app_spend, {
    app_spend_visible(!app_spend_visible())
  })
  observeEvent(input$toggle_dtc_revenue, {
    dtc_revenue_visible(!dtc_revenue_visible())
  })
  observeEvent(input$toggle_amazon_revenue, { # New toggle for Amazon Revenue
    amazon_revenue_visible(!amazon_revenue_visible())
  })
  observeEvent(input$toggle_dtc_spend, {
    dtc_spend_visible(!dtc_spend_visible())
  })
  observeEvent(input$toggle_fees, {
    fees_visible(!fees_visible())
  })
  observeEvent(input$toggle_digital_marketplaces, {
    digital_marketplaces_visible(!digital_marketplaces_visible())
  })
  observeEvent(input$toggle_b2b_revenue, {
    b2b_visible(!b2b_visible())
  })
  observeEvent(input$toggle_app_revenue, {
    app_revenue_visible(!app_revenue_visible())
  })
  
  # Function to calculate percentage change
  percentage_change <- function(current, previous) {
    if (is.na(previous) || previous == 0) {
      return(NA)
    }
    return((current - previous) / previous * 100)
  }
  
  # Reactive data for selected date
  selected_data <- reactive({
    req(input$selected_date_range)
    range_dates <- input$selected_date_range
    filtered_data <- revenue_data %>%
      filter(Date >= range_dates[1] & Date <= range_dates[2])
    
    total_revenue <- sum(filtered_data$Total_Revenue, na.rm = TRUE)
    total_spend <- sum(filtered_data$Total_Spend, na.rm = TRUE)
    dtc_revenue <- sum(filtered_data$DTC_Revenue, na.rm = TRUE)
    dtc_spend <- sum(filtered_data$Total_DTC_Spend, na.rm = TRUE)
    amazon_revenue <- sum(filtered_data$Amazon_Revenue, na.rm = TRUE)
    amazon_spend <- sum(filtered_data$Amazon_Spend, na.rm = TRUE)
    app_revenue <- sum(filtered_data$App_Revenue, na.rm = TRUE)
    app_spend <- sum(filtered_data$Total_App_Spend, na.rm = TRUE)
    
    # ROAS values
    blended_roas <- ifelse(total_spend == 0, NA, total_revenue / total_spend)
    wroas <- ifelse(dtc_spend == 0, NA, dtc_revenue / dtc_spend)
    aroas <- ifelse(amazon_spend == 0, NA, amazon_revenue / amazon_spend)
    approas <- ifelse(app_spend == 0, NA, app_revenue / app_spend)
    
    # CAC values based on your updated logic
    blended_cac <- ifelse(sum(filtered_data$Total_Orders, na.rm = TRUE) == 0, NA,
                          sum(filtered_data$Total_Spend, na.rm = TRUE) / sum(filtered_data$Total_Orders, na.rm = TRUE))
    wcac <- ifelse(sum(filtered_data$DTC_Orders, na.rm = TRUE) == 0, NA,
                   sum(filtered_data$Total_DTC_Spend, na.rm = TRUE) / sum(filtered_data$DTC_Orders, na.rm = TRUE))
    acac <- ifelse(sum(filtered_data$Amazon_Orders, na.rm = TRUE) == 0, NA,
                   sum(filtered_data$Amazon_Spend, na.rm = TRUE) / sum(filtered_data$Amazon_Orders, na.rm = TRUE))
    appcac <- ifelse(sum(filtered_data$App_Orders, na.rm = TRUE) == 0, NA,
                     sum(filtered_data$Total_App_Spend, na.rm = TRUE) / sum(filtered_data$App_Orders, na.rm = TRUE))
    
    
    # Weighted averages
    # New CR + AOV logic (based on orders)
    web_cr <- weighted.mean(filtered_data$Web_CR, w = filtered_data$DTC_Orders, na.rm = TRUE)
    web_aov <- mean(filtered_data$Web_AOV, na.rm = TRUE)
    fAOV <- weighted.mean(filtered_data$fAOV, w = filtered_data$DTC_Orders, na.rm = TRUE)
    rAOV <- weighted.mean(filtered_data$rAOV, w = filtered_data$DTC_Orders, na.rm = TRUE)
    # Calculate weighted % of returning customers (based on DTC orders)
    returning_customer_rate <- weighted.mean(filtered_data$Returning_Customers, w = filtered_data$DTC_Orders, na.rm = TRUE)
    
    
    
    
    # Summarize everything else
    current_summary <- filtered_data %>%
      summarise(across(where(is.numeric), ~sum(.x, na.rm = TRUE)))
    
    # Add calculated values
    current_summary$Blended_ROAS <- blended_roas
    current_summary$wROAS <- wroas
    current_summary$aROAS <- aroas
    current_summary$appROAS <- approas
    current_summary$Web_CR <- web_cr
    current_summary$Web_AOV <- web_aov
    current_summary$fAOV <- fAOV
    current_summary$rAOV <- rAOV
    
    current_summary$Blended_CAC <- blended_cac
    current_summary$wCAC <- wcac
    current_summary$aCAC <- acac
    current_summary$appCAC <- appcac
    current_summary$Returning_Customer_Rate <- returning_customer_rate
    
    
    list(
      current = current_summary,
      previous = NULL
    )
  })
  
  # Total Revenue Output
  output$total_revenue_output <- renderText({
    paste0(format(round(selected_data()$current$Total_Revenue, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  # Total Revenue Percentage Change
  output$total_percentage_change <- renderText({
    if (!is.null(selected_data()$previous)) {
      change <- percentage_change(selected_data()$current$Total_Revenue, selected_data()$previous$Total_Revenue)
      if (!is.na(change)) {
        paste0("(", format(round(change, 2), nsmall = 2), "%)")
      }
    }
  })
  
  # DTC Revenue Output
  output$dtc_revenue_output <- renderText({
    paste0(format(round(selected_data()$current$DTC_Revenue, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  # Dynamically render the container with DTC Revenue subcategories
  output$dtc_revenue_details <- renderUI({
    if (dtc_revenue_visible()) {
      div(
        style = "background-color: #d3d3d3; padding: 15px; border-radius: 10px; margin-top: 10px; width: 80%; margin-left: auto; margin-right: auto;",
        div(
          HTML(paste0("<strong>Hardware:</strong> ", format(round(selected_data()$current$DTC_Hardware, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Add-ons:</strong> ", format(round(selected_data()$current$DTC_Addons, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Merchandise:</strong> ", format(round(selected_data()$current$DTC_Merch, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Seeds:</strong> ", format(round(selected_data()$current$DTC_Seeds, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Taxes:</strong> ", format(round(selected_data()$current$DTC_Taxes, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Shipping:</strong> ", format(round(selected_data()$current$DTC_Shipping, 2), nsmall = 2, big.mark = ","), " $"))
        )
      )
    } else {
      NULL
    }
  })
  
  # Amazon Revenue Output
  output$amazon_revenue_output <- renderText({
    paste0(format(round(selected_data()$current$Amazon_Revenue, 2), nsmall = 2, big.mark = ","), " $")
  })
  # Dynamically render the container with Amazon Revenue subcategories
  output$amazon_revenue_details <- renderUI({
    if (amazon_revenue_visible()) {
      div(
        style = "background-color: #d3d3d3; padding: 15px; border-radius: 10px; margin-top: 10px; width: 80%; margin-left: auto; margin-right: auto;",
        div(
          HTML(paste0("<strong>Hardware:</strong> ", format(round(selected_data()$current$Amazon_Hardware, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Add-ons:</strong> ", format(round(selected_data()$current$Amazon_Addons, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Tax:</strong> ", format(round(selected_data()$current$Amazon_Tax, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Shipping:</strong> ", format(round(selected_data()$current$Amazon_Shipping, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Gift Wrap:</strong> ", format(round(selected_data()$current$Amazon_GiftWrap, 2), nsmall = 2, big.mark = ","), " $"))
        )
      )
    } else {
      NULL
    }
  })
  
  # Digital Marketplaces Revenue Output
  output$digital_marketplaces_output <- renderText({
    paste0(format(round(selected_data()$current$Digital_Marketplaces_Revenue, 2), nsmall = 2, big.mark = ","), " $")
  })
  output$digital_marketplaces_details <- renderUI({
    if (digital_marketplaces_visible()) {
      div(
        style = "background-color: #d3d3d3; padding: 15px; border-radius: 10px; margin-top: 10px; width: 80%; margin-left: auto; margin-right: auto;",
        div(HTML(paste0("<strong>Rachio Revenue:</strong> ", format(round(selected_data()$current$Rachio_Revenue, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Weatherflow Revenue:</strong> ", format(round(selected_data()$current$Weatherflow_Revenue, 2), nsmall = 2, big.mark = ","), " $")))
      )
    } else {
      NULL
    }
  })
  
  # B2B Revenue Output
  output$b2b_revenue_output <- renderText({
    paste0(format(round(selected_data()$current$B2B_Revenue, 2), nsmall = 2, big.mark = ","), " $")
  })
  output$b2b_revenue_details <- renderUI({
    if (b2b_visible()) {
      div(
        style = "
        background-color: #d3d3d3;
        padding: 20px;
        border-radius: 15px;
        margin-top: 1px;
        width: 130%;
        max-width: 700px;
        text-align: left;
        box-shadow: 0 2px 6px rgba(0,0,0,0.1);
      ",
        div(HTML(paste0("<strong>BestBuy Revenue: </strong>", 
                        format(round(selected_data()$current$BestBuy_Revenue, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Target Revenue: </strong>", 
                        format(round(selected_data()$current$Target_Revenue, 2), nsmall = 2, big.mark = ","), " $")))
      )
    } else {
      NULL
    }
  })
  
  # App Revenue Output
  output$app_revenue_output <- renderText({
    paste0(format(round(selected_data()$current$App_Revenue, 2), nsmall = 2, big.mark = ","), " $")
  })
  output$app_revenue_details <- renderUI({
    if (app_revenue_visible()) {
      div(
        style = "
        background-color: #d3d3d3;
        padding: 20px;
        border-radius: 15px;
        margin-top: 1px;
        width: 130%;
        max-width: 700px;
        text-align: right;
        float: right;
        box-shadow: 0 2px 6px rgba(0,0,0,0.1);
      ",
        div(HTML(paste0("<strong>Google Store:</strong> ",
                        format(round(selected_data()$current$Google_Store, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Apple Store:</strong> ",
                        format(round(selected_data()$current$Apple_Store, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Commission:</strong> ",
                        format(round(selected_data()$current$App_Comission, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Tax:</strong> ",
                        format(round(selected_data()$current$App_Tax, 2), nsmall = 2, big.mark = ","), " $")))
      )
    } else {
      NULL
    }
  })
  
  # Total Spend Output
  output$total_spend_output <- renderText({
    paste0(format(round(selected_data()$current$Total_Spend, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  # Total Spend Percentage Change
  output$total_spend_percentage_change <- renderText({
    if (!is.null(selected_data()$previous)) {
      change <- percentage_change(selected_data()$current$Total_Spend, selected_data()$previous$Total_Spend)
      if (!is.na(change)) {
        paste0("(", format(round(change, 2), nsmall = 2), "%)")
      }
    }
  })
  
  # DTC Spend Output
  output$dtc_spend_output <- renderText({
    paste0(format(round(selected_data()$current$Total_DTC_Spend, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  output$dtc_spend_details <- renderUI({
    if (dtc_spend_visible()) {
      div(
        style = "background-color: #d3d3d3; padding: 15px; border-radius: 10px; margin-top: 10px; width: 80%; margin-left: auto; margin-right: auto;",
        div(HTML(paste0("<strong>Meta Spend:</strong> ", format(round(selected_data()$current$Meta_Spend, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Google Spend:</strong> ", format(round(selected_data()$current$Google_Spend, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Bing Spend:</strong> ", format(round(selected_data()$current$Bing_Spend, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>TikTok Spend:</strong> ", format(round(selected_data()$current$TikTok_Spend, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Nextdoor Spend:</strong> ", format(round(selected_data()$current$Nextdoor_Spend, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Affiliate Fees:</strong> ", format(round(selected_data()$current$Affiliate_Fees, 2), nsmall = 2, big.mark = ","), " $")))
      )
    } else {
      NULL
    }
  })
  
  # Amazon Spend Output
  output$amazon_spend_output <- renderText({
    paste0(format(round(selected_data()$current$Amazon_Spend, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  
  output$indiegogo_spend_output <- renderText({
    paste0(format(round(selected_data()$current$IndieGoGo_Spend, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  output$fees_output <- renderText({
    paste0(format(round(selected_data()$current$Fees, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  output$fees_details <- renderUI({
    if (fees_visible()) {
      div(
        style = "background-color: #d3d3d3; padding: 15px; border-radius: 10px; margin-top: 10px; width: 80%; margin-left: auto; margin-right: auto;",
        div(HTML(paste0("<strong>Rachio Fees:</strong> ", format(round(selected_data()$current$Rachio_Fees, 2), nsmall = 2), " $"))),
        div(HTML(paste0("<strong>Weatherflow Fees:</strong> ", format(round(selected_data()$current$Weatherflow_Fees, 2), nsmall = 2), " $")))
      )
    } else {
      NULL
    }
  })
  
  # Total App Spend Output
  output$total_app_spend_output <- renderText({
    paste0(format(round(selected_data()$current$Total_App_Spend, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  # Dynamically render the gray container with app spend details
  output$app_spend_details <- renderUI({
    if (app_spend_visible()) {
      div(
        style = "background-color: #d3d3d3; padding: 10px; border-radius: 10px; margin-top: 10px; width: 40%; margin-left: auto; margin-right: auto;",
        div(
          HTML(paste0("<strong>Meta App Spend:</strong> ", format(round(selected_data()$current$App_Spend_Meta, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Apple App Spend:</strong> ", format(round(selected_data()$current$App_Spend_Apple, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Google App Spend:</strong> ", format(round(selected_data()$current$App_Spend_Google, 2), nsmall = 2, big.mark = ","), " $"))
        )
      )
    } else {
      NULL
    }
  })
  
  
  
  # Populate date dropdown choices dynamically
  observe({
    updateSelectInput(session, "selected_date", choices = revenue_data$Date, selected = revenue_data$Date[1])
  })
  # Blended ROAS
  output$blended_roas_output <- renderText({
    paste0(format(round(selected_data()$current$Blended_ROAS, 2), nsmall = 2, big.mark = ","))
  })
  
  # Blended CAC
  output$blended_cac_output <- renderText({
    paste0(format(round(selected_data()$current$Blended_CAC, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  # Web CR
  output$web_cr_output <- renderText({
    paste0(format(round(selected_data()$current$Web_CR * 100, 2), nsmall = 2), " %")  # Assuming Web CR is a ratio
  })
  
  # Web AOV
  output$web_aov_output <- renderText({
    paste0(format(round(selected_data()$current$Web_AOV, 2), nsmall = 2, big.mark = ","), " $")
  })
  # ---- Reactive Value for Blended ROAS Visibility ----
  blended_roas_visible <- reactiveVal(FALSE)
  
  # Toggle visibility when the button is clicked
  observeEvent(input$toggle_blended_roas, {
    blended_roas_visible(!blended_roas_visible())
  })
  
  # Dynamically render the container with Blended ROAS details
  output$blended_roas_details <- renderUI({
    if (blended_roas_visible()) {
      div(
        style = "
        background-color: #ffffff;
        padding: 10px;
        border-radius: 10px;
        margin-top: 10px;
        text-align: center;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>wROAS:</strong> ", format(round(selected_data()$current$wROAS, 2), nsmall = 2)))),
        div(HTML(paste0("<strong>aROAS:</strong> ", format(round(selected_data()$current$aROAS, 2), nsmall = 2)))),
        div(HTML(paste0("<strong>appROAS:</strong> ", format(round(selected_data()$current$appROAS, 2), nsmall = 2))))
      )
    } else {
      NULL
    }
  })
  # ---- Reactive Value for Blended CAC Visibility ----
  # Reactive toggle for CAC details
  blended_cac_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_blended_cac, {
    blended_cac_visible(!blended_cac_visible())
  })
  output$blended_cac_details <- renderUI({
    if (blended_cac_visible()) {
      div(
        style = "
        background-color: #ffffff;
        padding: 10px;
        border-radius: 10px;
        margin-top: 10px;
        text-align: center;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>wCAC:</strong> ", format(round(selected_data()$current$wCAC, 2), nsmall = 2), " $"))),
        div(HTML(paste0("<strong>aCAC:</strong> ", format(round(selected_data()$current$aCAC, 2), nsmall = 2), " $"))),
        div(HTML(paste0("<strong>appCAC:</strong> ", format(round(selected_data()$current$appCAC, 2), nsmall = 2), " $")))
      )
    } else {
      NULL
    }
  })
  
  # ---- Reactive Value for Web AOV Visibility ----
  web_aov_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_web_aov, {
    web_aov_visible(!web_aov_visible())
  })
  
  output$web_aov_details <- renderUI({
    if (web_aov_visible()) {
      div(
        style = "
        background-color: #ffffff;
        padding: 10px;
        border-radius: 10px;
        margin-top: 10px;
        text-align: center;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>fAOV:</strong> ", format(round(selected_data()$current$fAOV, 2), nsmall = 2), " $"))),
        div(HTML(paste0("<strong>rAOV:</strong> ", format(round(selected_data()$current$rAOV, 2), nsmall = 2), " $")))
      )
    } else {
      NULL
    }
  })
  
  
  # Orders Outputs
  output$dtc_orders_output <- renderText({
    format(round(sum(selected_data()$current$DTC_Orders, na.rm = TRUE), 0), big.mark = ",")
  })
  
  output$amazon_orders_output <- renderText({
    format(round(sum(selected_data()$current$Amazon_Orders, na.rm = TRUE), 0), big.mark = ",")
  })
  
  output$digital_marketplaces_orders_output <- renderText({
    format(round(sum(selected_data()$current$Digital_Marketplaces_Orders, na.rm = TRUE), 0), big.mark = ",")
  })
  
  output$b2b_orders_output <- renderText({
    format(round(sum(selected_data()$current$B2B_Orders, na.rm = TRUE), 0), big.mark = ",")
  })
  
  output$app_orders_output <- renderText({
    format(round(sum(selected_data()$current$App_Orders, na.rm = TRUE), 0), big.mark = ",")
  })
  
  output$dtc_orders_details <- renderUI({
    if (dtc_orders_visible()) {
      div(
        style = "
        background-color: #d3d3d3;
        padding: 15px;
        border-radius: 10px;
        margin-top: 10px;
        width: 80%;
        margin-left: auto;
        margin-right: auto;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>Hardware:</strong> ", format(round(selected_data()$current$DTC_Hardware_Units, 0), big.mark = ","), " units"))),
        div(HTML(paste0("<strong>Add-ons:</strong> ", format(round(selected_data()$current$DTC_Addons_Units, 0), big.mark = ","), " units"))),
        div(HTML(paste0("<strong>Merch:</strong> ", format(round(selected_data()$current$DTC_Merch_Units, 0), big.mark = ","), " units"))),
        div(HTML(paste0("<strong>Seeds:</strong> ", format(round(selected_data()$current$DTC_Seeds_Units, 0), big.mark = ","), " units")))
      )
    } else {
      NULL
    }
  })
  
  output$amazon_orders_details <- renderUI({
    if (amazon_orders_visible()) {
      div(
        style = "
        background-color: #d3d3d3;
        padding: 15px;
        border-radius: 10px;
        margin-top: 10px;
        width: 80%;
        margin-left: auto;
        margin-right: auto;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>Hardware:</strong> ", format(round(selected_data()$current$Amazon_Hardware_Units, 0), big.mark = ","), " units"))),
        div(HTML(paste0("<strong>Add-ons:</strong> ", format(round(selected_data()$current$Amazon_Addons_Units, 0), big.mark = ","), " units")))
      )
    } else {
      NULL
    }
  })
  
  output$digital_marketplaces_orders_details <- renderUI({
    if (digital_marketplaces_orders_visible()) {
      div(
        style = "
        background-color: #d3d3d3;
        padding: 15px;
        border-radius: 10px;
        margin-top: 10px;
        width: 80%;
        margin-left: auto;
        margin-right: auto;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>Rachio Orders:</strong> ", format(round(selected_data()$current$Rachio_Orders, 0), big.mark = ",")))),
        div(HTML(paste0("<strong>Weatherflow Orders:</strong> ", format(round(selected_data()$current$Weatherflow_Orders, 0), big.mark = ","))))
      )
    } else {
      NULL
    }
  })
  
  output$b2b_orders_details <- renderUI({
    if (b2b_orders_visible()) {
      div(
        style = "
        background-color: #d3d3d3;
        padding: 15px;
        border-radius: 10px;
        margin-top: 10px;
        width: 80%;
        margin-left: auto;
        margin-right: auto;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>Best Buy Orders:</strong> ", format(round(selected_data()$current$BestBuy_Orders, 0), big.mark = ",")))),
        div(HTML(paste0("<strong>Target Orders:</strong> ", format(round(selected_data()$current$Target_Orders, 0), big.mark = ","))))
      )
    } else {
      NULL
    }
  })
  
  output$app_orders_details <- renderUI({
    if (app_orders_visible()) {
      div(
        style = "
        background-color: #d3d3d3;
        padding: 15px;
        border-radius: 10px;
        margin-top: 10px;
        width: 80%;
        margin-left: auto;
        margin-right: auto;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>Google Store Orders:</strong> ", format(round(selected_data()$current$Google_Store_Orders, 0), big.mark = ",")))),
        div(HTML(paste0("<strong>Apple Store Orders:</strong> ", format(round(selected_data()$current$Apple_Store_Orders, 0), big.mark = ","))))
      )
    } else {
      NULL
    }
  })
  
  output$revenue_vs_spend_plot <- renderPlotly({
    req(input$selected_date_range)
    req(input$selected_revenue_spend_type)
    req(input$selected_view_mode)
    
    selected_type <- input$selected_revenue_spend_type
    view_mode <- input$selected_view_mode
    
    cols <- switch(selected_type,
                   "Total" = c("Total_Revenue", "Total_Spend"),
                   "DTC" = c("DTC_Revenue", "Total_DTC_Spend"),
                   "Amazon" = c("Amazon_Revenue", "Amazon_Spend"),
                   "App" = c("App_Revenue", "Total_App_Spend"),
                   "B2B" = c("B2B_Revenue", NA)  # No spend data for B2B
    )
    
    df <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(Date = as.Date(Date))
    
    if (is.na(cols[2])) {
      df <- df %>%
        select(Date, Revenue = all_of(cols[1])) %>%
        mutate(Spend = 0)  # Fill spend with 0s
    } else {
      df <- df %>%
        select(Date, Revenue = all_of(cols[1]), Spend = all_of(cols[2]))
    }
    
    
    if (view_mode == "Absolute") {
      df_long <- df %>%
        pivot_longer(cols = c(Revenue, Spend), names_to = "Metric", values_to = "Amount") %>%
        mutate(
          Tooltip = paste0(
            "<span style='font-family: Montserrat;'><b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
            "<b>", Metric, ":</b> $", format(round(Amount, 2), big.mark = ",", nsmall = 2),
            "</span>"
          )
        )
      
      p <- ggplot(df_long, aes(x = Date, y = Amount, color = Metric, group = Metric, text = Tooltip)) +
        geom_line(size = 1.2) +
        geom_point(size = 2) +
        scale_color_manual(values = c("Revenue" = "#2ecc71", "Spend" = "#A52A2A")) +
        scale_y_continuous(labels = scales::label_dollar()) +
        scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
        theme_minimal(base_family = "Montserrat") +
        theme(
          axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
          axis.text.y = element_text(size = 12),
          legend.position = "none",
          panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
          plot.background = element_rect(fill = "#ffffff", color = NA),
          panel.background = element_rect(fill = "#ffffff", color = NA)
        )
      
      ggplotly(p, tooltip = "text") %>%
        layout(
          margin = list(l = 40, r = 20, t = 20, b = 60),
          yaxis = list(title = list(text = "")), 
          xaxis = list(title = list(text = "")),
          plot_bgcolor = "#ffffff",
          paper_bgcolor = "#ffffff"
        )
      
    } else {
      df <- df %>%
        mutate(
          Total = Revenue + Spend,
          Revenue_Perc = ifelse(Total == 0, 0, Revenue / Total),
          Spend_Perc = ifelse(Total == 0, 0, Spend / Total),
          Revenue_Label = paste0(
            "<b>", format(Date, "%b %d, %Y"), "</b><br>",
            "<span style='color:#2ecc71;'>Revenue: $", format(round(Revenue, 2), big.mark = ","), 
            " (", round(Revenue_Perc * 100, 1), "%)</span>"
          ),
          Spend_Label = paste0(
            "<b>", format(Date, "%b %d, %Y"), "</b><br>",
            "<span style='color:#A52A2A;'>Spend: $", format(round(Spend, 2), big.mark = ","), 
            " (", round(Spend_Perc * 100, 1), "%)</span>"
          )
        )
      
      plot_ly() %>%
        add_trace(
          data = df,
          x = ~Date, y = ~Revenue_Perc,
          type = 'scatter', mode = 'none',
          name = 'Revenue',
          stackgroup = 'one',
          fillcolor = 'rgba(46, 204, 113, 0.3)',
          line = list(color = '#2ecc71'),
          text = ~Revenue_Label,
          hoverinfo = 'text'
        ) %>%
        add_trace(
          data = df,
          x = ~Date, y = ~Spend_Perc,
          type = 'scatter', mode = 'none',
          name = 'Spend',
          stackgroup = 'one',
          fillcolor = 'rgba(165, 42, 42, 0.3)',
          line = list(color = '#A52A2A'),
          text = ~Spend_Label,
          hoverinfo = 'text'
        ) %>%
        layout(
          yaxis = list(
            title = "", tickformat = ".0%", tickfont = list(family = "Montserrat", size = 16),
            showline = TRUE, showgrid = TRUE
          ),
          xaxis = list(
            title = "", tickfont = list(family = "Montserrat", size = 16),
            showline = TRUE
          ),
          hovermode = "x unified",
          showlegend = FALSE,
          margin = list(l = 40, r = 20, t = 20, b = 60),
          plot_bgcolor = "#ffffff",
          paper_bgcolor = "#ffffff",
          font = list(family = "Montserrat")
        )
    }
  })
  
  
  
  output$blended_roas_bar_chart <- renderPlotly({
    req(input$selected_date_range)
    req(input$selected_roas_type)
    
    filtered_data <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(
        Date = as.Date(Date),
        Blended_ROAS = ifelse(Total_Spend == 0, NA, Total_Revenue / Total_Spend),
        wROAS = ifelse(Total_DTC_Spend == 0, NA, DTC_Revenue / Total_DTC_Spend),
        aROAS = ifelse(Amazon_Spend == 0, NA, Amazon_Revenue / Amazon_Spend),
        appROAS = ifelse(Total_App_Spend == 0, NA, App_Revenue / Total_App_Spend)
      )
    
    selected_metric <- input$selected_roas_type
    
    plot_data <- filtered_data %>%
      select(Date, !!selected_metric) %>%
      rename(ROAS = !!selected_metric) %>%
      mutate(
        Tooltip = paste0(
          "<span style='font-family: Montserrat;'>",
          "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
          "<b>", gsub("_", " ", selected_metric), ":</b> ", round(ROAS, 2),
          "</span>"
        )
      )
    
    p <- ggplot(plot_data, aes(x = Date, y = ROAS, text = Tooltip)) +
      geom_col(fill = "#2ecc71", width = 0.6) +
      scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
      scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
      labs(x = NULL, y = NULL) +
      theme_minimal(base_family = "Montserrat") +
      theme_minimal(base_family = "Montserrat") +
      theme(
        plot.title = element_blank(),
        axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
        axis.text.y = element_text(size = 12),
        panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
        plot.background = element_rect(fill = "#ffffff", color = NA),
        panel.background = element_rect(fill = "#ffffff", color = NA)
      )
    
    
    ggplotly(p, tooltip = "text") %>%
      layout(
        margin = list(l = 40, r = 20, t = 20, b = 60),
        plot_bgcolor = "#ffffff",
        paper_bgcolor = "#ffffff"
      )
  })
  
  output$returning_customer_output <- renderText({
    paste0(format(round(selected_data()$current$Returning_Customer_Rate * 100, 2), nsmall = 2), " %")
  })
  
  
  
  
  
  output$revenue_share_chart <- renderPlotly({
    req(input$selected_date_range)
    view_mode <- input$selected_revenue_view_mode
    
    filtered_data <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(Date = as.Date(Date))
    
    if (view_mode == "Absolute") {
      # ----- ABSOLUTE MODE: LINE CHART -----
      df_long <- filtered_data %>%
        select(Date, DTC_Revenue, Amazon_Revenue, Digital_Marketplaces_Revenue) %>%
        pivot_longer(cols = -Date, names_to = "Category", values_to = "Revenue") %>%
        mutate(
          Category = recode(Category,
                            DTC_Revenue = "DTC",
                            Amazon_Revenue = "Amazon",
                            Digital_Marketplaces_Revenue = "Digital Marketplaces"),
          Tooltip = paste0(
            "<span style='font-family: Montserrat;'>",
            "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
            "<b>", Category, ":</b> $", format(round(Revenue, 2), big.mark = ","),
            "</span>"
          )
        )
      
      p <- ggplot(df_long, aes(x = Date, y = Revenue, color = Category, group = Category, text = Tooltip)) +
        geom_line(size = 1.2) +
        geom_point(size = 2) +
        scale_color_manual(values = c("DTC" = "#2ecc71", "Amazon" = "#3498db", "Digital Marketplaces" = "#f39c12")) +
        scale_y_continuous(labels = scales::label_dollar()) +
        scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
        labs(x = NULL, y = NULL) +
        theme_minimal(base_family = "Montserrat") +
        theme(
          axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
          axis.text.y = element_text(size = 12),
          legend.title = element_blank(),
          panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
          plot.background = element_rect(fill = "#ffffff", color = NA),
          panel.background = element_rect(fill = "#ffffff", color = NA)
        )
      
      ggplotly(p, tooltip = "text") %>%
        layout(
          margin = list(l = 40, r = 20, t = 60, b = 60),
          plot_bgcolor = "#ffffff",
          paper_bgcolor = "#ffffff",
          legend = list(
            orientation = "h",
            x = 0.5,
            y = 1.15,
            xanchor = "center",
            font = list(family = "Montserrat", size = 14),
            title = list(text = NULL)  # <-- Hides legend title
          ),
          font = list(family = "Montserrat")
        )
      
    } else {
      # ----- RELATIVE MODE (existing logic) -----
      filtered_data <- filtered_data %>%
        mutate(
          Total = DTC_Revenue + Amazon_Revenue + Digital_Marketplaces_Revenue,
          DTC_Perc = ifelse(Total == 0, 0, DTC_Revenue / Total),
          Amazon_Perc = ifelse(Total == 0, 0, Amazon_Revenue / Total),
          DM_Perc = ifelse(Total == 0, 0, Digital_Marketplaces_Revenue / Total),
          
          DTC_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#2ecc71;'>DTC Revenue: $", format(round(DTC_Revenue, 2), big.mark = ","), " (", round(DTC_Perc * 100, 1), "%)</span>"),
          Amazon_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#3498db;'>Amazon Revenue: $", format(round(Amazon_Revenue, 2), big.mark = ","), " (", round(Amazon_Perc * 100, 1), "%)</span>"),
          DM_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#f39c12;'>Digital Marketplaces Revenue: $", format(round(Digital_Marketplaces_Revenue, 2), big.mark = ","), " (", round(DM_Perc * 100, 1), "%)</span>")
        )
      
      plot_ly() %>%
        add_trace(data = filtered_data, x = ~Date, y = ~DTC_Perc, type = 'scatter', mode = 'none', name = 'DTC',
                  stackgroup = 'one', fillcolor = 'rgba(46, 204, 113, 0.3)', line = list(color = '#2ecc71'), text = ~DTC_Label, hoverinfo = 'text') %>%
        add_trace(data = filtered_data, x = ~Date, y = ~Amazon_Perc, type = 'scatter', mode = 'none', name = 'Amazon',
                  stackgroup = 'one', fillcolor = 'rgba(52, 152, 219, 0.3)', line = list(color = '#3498db'), text = ~Amazon_Label, hoverinfo = 'text') %>%
        add_trace(data = filtered_data, x = ~Date, y = ~DM_Perc, type = 'scatter', mode = 'none', name = 'Digital Marketplaces',
                  stackgroup = 'one', fillcolor = 'rgba(243, 156, 18, 0.3)', line = list(color = '#f39c12'), text = ~DM_Label, hoverinfo = 'text') %>%
        layout(
          yaxis = list(title = list(text = ""), tickformat = ".0%", tickfont = list(family = "Montserrat", size = 16)),
          xaxis = list(title = list(text = ""), tickfont = list(family = "Montserrat", size = 16)),
          hovermode = "x unified",
          showlegend = TRUE,
          legend = list(orientation = "h", x = 0.5, y = 1.15, xanchor = "center", font = list(family = "Montserrat", size = 14)),
          margin = list(l = 40, r = 20, t = 60, b = 60),
          plot_bgcolor = "#ffffff",
          paper_bgcolor = "#ffffff",
          font = list(family = "Montserrat")
        )
    }
  })
  
  
  
  output$spend_composition_chart <- renderPlotly({
    req(input$selected_date_range)
    req(input$selected_spend_composition)
    req(input$selected_spend_view_mode)
    
    view_mode <- input$selected_spend_view_mode
    spend_type <- input$selected_spend_composition
    
    df <- revenue_data %>%
      filter(Date >= input$selected_date_range[1], Date <= input$selected_date_range[2]) %>%
      mutate(Date = as.Date(Date))
    
    if (view_mode == "Absolute") {
      if (spend_type == "Total") {
        df_long <- df %>%
          select(Date, DTC = Total_DTC_Spend, Amazon = Amazon_Spend, App = Total_App_Spend, Fees) %>%
          pivot_longer(-Date, names_to = "Category", values_to = "Spend") %>%
          mutate(
            Tooltip = paste0(
              "<span style='font-family: Montserrat;'>",
              "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
              "<b>", Category, ":</b> $", format(round(Spend, 2), big.mark = ","),
              "</span>"
            )
          )
        
        p <- ggplot(df_long, aes(x = Date, y = Spend, color = Category, group = Category, text = Tooltip)) +
          geom_line(size = 1.2) +
          geom_point(size = 2) +
          scale_color_manual(values = c("DTC" = "#A52A2A", "Amazon" = "#f39c12", "App" = "#9b59b6", "Fees" = "#34495e")) +
          scale_y_continuous(labels = scales::label_dollar()) +
          scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
          labs(x = NULL, y = NULL) +
          theme_minimal(base_family = "Montserrat") +
          theme(
            axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
            axis.text.y = element_text(size = 12),
            legend.title = element_blank(),
            panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
            plot.background = element_rect(fill = "#ffffff", color = NA),
            panel.background = element_rect(fill = "#ffffff", color = NA)
          )
        
        return(ggplotly(p, tooltip = "text") %>%
                 layout(
                   margin = list(l = 40, r = 20, t = 60, b = 60),
                   plot_bgcolor = "#ffffff",
                   paper_bgcolor = "#ffffff",
                   legend = list(
                     orientation = "h",
                     x = 0.5,
                     y = 1.15,
                     xanchor = "center",
                     font = list(family = "Montserrat", size = 14),
                     title = list(text = NULL)  # <-- Hides legend title
                   ),
                   font = list(family = "Montserrat")
                 ))
        
        
      } else if (spend_type == "DTC") {
        df_long <- df %>%
          select(Date,
                 Meta = Meta_Spend,
                 Google = Google_Spend,
                 Bing = Bing_Spend,
                 TikTok = TikTok_Spend,
                 Nextdoor = Nextdoor_Spend,
                 Affiliate = Affiliate_Fees) %>%
          pivot_longer(-Date, names_to = "Channel", values_to = "Spend") %>%
          mutate(
            Tooltip = paste0(
              "<span style='font-family: Montserrat;'>",
              "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
              "<b>", Channel, ":</b> $", format(round(Spend, 2), big.mark = ","),
              "</span>"
            )
          )
        
        p <- ggplot(df_long, aes(x = Date, y = Spend, color = Channel, group = Channel, text = Tooltip)) +
          geom_line(size = 1.2) +
          geom_point(size = 2) +
          scale_color_manual(values = c("Meta" = "#2ecc71", "Google" = "#3498db", "Bing" = "#9b59b6",
                                        "TikTok" = "#e74c3c", "Nextdoor" = "#f1c40f", "Affiliate" = "#34495e")) +
          scale_y_continuous(labels = scales::label_dollar()) +
          scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
          labs(x = NULL, y = NULL) +
          theme_minimal(base_family = "Montserrat") +
          theme(
            axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
            axis.text.y = element_text(size = 12),
            legend.title = element_blank(),
            panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
            plot.background = element_rect(fill = "#ffffff", color = NA),
            panel.background = element_rect(fill = "#ffffff", color = NA)
          )
        
        return(ggplotly(p, tooltip = "text") %>%
                 layout(
                   margin = list(l = 40, r = 20, t = 60, b = 60),
                   plot_bgcolor = "#ffffff",
                   paper_bgcolor = "#ffffff",
                   legend = list(
                     orientation = "h",
                     x = 0.5,
                     y = 1.15,
                     xanchor = "center",
                     font = list(family = "Montserrat", size = 14),
                     title = list(text = NULL)  # <-- Hides legend title
                   ),
                   font = list(family = "Montserrat")
                 ))
        
      }
    } else {
      if (spend_type == "Total") {
        df <- df %>%
          filter(!is.na(Total_Spend) & Total_Spend > 0) %>%
          mutate(
            DTC_Perc = Total_DTC_Spend / Total_Spend,
            Amazon_Perc = Amazon_Spend / Total_Spend,
            App_Perc = Total_App_Spend / Total_Spend,
            Fees_Perc = Fees / Total_Spend
          ) %>%
          rowwise() %>%
          mutate(
            Total_Percent = sum(c_across(ends_with("_Perc")), na.rm = TRUE),
            Scale_Factor = ifelse(Total_Percent > 1, 1 / Total_Percent, 1),
            DTC_Perc = DTC_Perc * Scale_Factor,
            Amazon_Perc = Amazon_Perc * Scale_Factor,
            App_Perc = App_Perc * Scale_Factor,
            Fees_Perc = Fees_Perc * Scale_Factor
          ) %>%
          ungroup() %>%
          mutate(
            DTC_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br>",
                               "<span style='color:#A52A2A;'>DTC Spend:</span> $", format(round(Total_DTC_Spend, 2), big.mark = ","),
                               " (", round(DTC_Perc * 100, 1), "%)"),
            Amazon_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br>",
                                  "<span style='color:#f39c12;'>Amazon Spend:</span> $", format(round(Amazon_Spend, 2), big.mark = ","),
                                  " (", round(Amazon_Perc * 100, 1), "%)"),
            App_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br>",
                               "<span style='color:#9b59b6;'>App Spend:</span> $", format(round(Total_App_Spend, 2), big.mark = ","),
                               " (", round(App_Perc * 100, 1), "%)"),
            Fees_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br>",
                                "<span style='color:#34495e;'>Fees:</span> $", format(round(Fees, 2), big.mark = ","),
                                " (", round(Fees_Perc * 100, 1), "%)")
          )
        
        return(plot_ly() %>%
                 add_trace(data = df, x = ~Date, y = ~DTC_Perc, type = "scatter", mode = "none", name = "DTC Spend",
                           stackgroup = "one", fillcolor = "rgba(165, 42, 42, 0.3)", line = list(color = "#A52A2A"),
                           text = ~DTC_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~Amazon_Perc, type = "scatter", mode = "none", name = "Amazon Spend",
                           stackgroup = "one", fillcolor = "rgba(243, 156, 18, 0.3)", line = list(color = "#f39c12"),
                           text = ~Amazon_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~App_Perc, type = "scatter", mode = "none", name = "App Spend",
                           stackgroup = "one", fillcolor = "rgba(155, 89, 182, 0.3)", line = list(color = "#9b59b6"),
                           text = ~App_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~Fees_Perc, type = "scatter", mode = "none", name = "Fees",
                           stackgroup = "one", fillcolor = "rgba(52, 73, 94, 0.3)", line = list(color = "#34495e"),
                           text = ~Fees_Label, hoverinfo = "text") %>%
                 layout(
                   yaxis = list(title = list(text = ""),tickformat = ".0%", tickfont = list(family = "Montserrat", size = 14)),
                   xaxis = list(title = list(text = ""),tickfont = list(family = "Montserrat", size = 14)),
                   hovermode = "x unified",
                   showlegend = TRUE,
                   legend = list(orientation = "h", x = 0.5, y = 1.1, xanchor = "center",
                                 font = list(family = "Montserrat", size = 14)),
                   margin = list(l = 40, r = 20, t = 60, b = 60),
                   plot_bgcolor = "#ffffff",
                   paper_bgcolor = "#ffffff",
                   font = list(family = "Montserrat")
                 ))
      } else if (spend_type == "DTC") {
        df <- df %>%
          filter(!is.na(Total_DTC_Spend) & Total_DTC_Spend > 0) %>%
          mutate(
            Meta_Perc = Meta_Spend / Total_DTC_Spend,
            Google_Perc = Google_Spend / Total_DTC_Spend,
            Bing_Perc = Bing_Spend / Total_DTC_Spend,
            TikTok_Perc = TikTok_Spend / Total_DTC_Spend,
            Nextdoor_Perc = Nextdoor_Spend / Total_DTC_Spend,
            Affiliate_Perc = Affiliate_Fees / Total_DTC_Spend
          ) %>%
          rowwise() %>%
          mutate(
            Total_Percent = sum(c_across(ends_with("_Perc")), na.rm = TRUE),
            Scale_Factor = ifelse(Total_Percent > 1, 1 / Total_Percent, 1),
            Meta_Perc = Meta_Perc * Scale_Factor,
            Google_Perc = Google_Perc * Scale_Factor,
            Bing_Perc = Bing_Perc * Scale_Factor,
            TikTok_Perc = TikTok_Perc * Scale_Factor,
            Nextdoor_Perc = Nextdoor_Perc * Scale_Factor,
            Affiliate_Perc = Affiliate_Perc * Scale_Factor
          ) %>%
          ungroup() %>%
          mutate(
            Meta_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#2ecc71;'>Meta Spend:</span> $", format(round(Meta_Spend, 2), big.mark = ","), " (", round(Meta_Perc * 100, 1), "%)"),
            Google_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#3498db;'>Google Spend:</span> $", format(round(Google_Spend, 2), big.mark = ","), " (", round(Google_Perc * 100, 1), "%)"),
            Bing_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#9b59b6;'>Bing Spend:</span> $", format(round(Bing_Spend, 2), big.mark = ","), " (", round(Bing_Perc * 100, 1), "%)"),
            TikTok_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#e74c3c;'>TikTok Spend:</span> $", format(round(TikTok_Spend, 2), big.mark = ","), " (", round(TikTok_Perc * 100, 1), "%)"),
            Nextdoor_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#f1c40f;'>Nextdoor Spend:</span> $", format(round(Nextdoor_Spend, 2), big.mark = ","), " (", round(Nextdoor_Perc * 100, 1), "%)"),
            Affiliate_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#34495e;'>Affiliate Fees:</span> $", format(round(Affiliate_Fees, 2), big.mark = ","), " (", round(Affiliate_Perc * 100, 1), "%)")
          )
        
        return(plot_ly() %>%
                 add_trace(data = df, x = ~Date, y = ~Meta_Perc, type = "scatter", mode = "none", name = "Meta Spend",
                           stackgroup = "one", fillcolor = "rgba(46, 204, 113, 0.3)", line = list(color = "#2ecc71"),
                           text = ~Meta_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~Google_Perc, type = "scatter", mode = "none", name = "Google Spend",
                           stackgroup = "one", fillcolor = "rgba(52, 152, 219, 0.3)", line = list(color = "#3498db"),
                           text = ~Google_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~Bing_Perc, type = "scatter", mode = "none", name = "Bing Spend",
                           stackgroup = "one", fillcolor = "rgba(155, 89, 182, 0.3)", line = list(color = "#9b59b6"),
                           text = ~Bing_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~TikTok_Perc, type = "scatter", mode = "none", name = "TikTok Spend",
                           stackgroup = "one", fillcolor = "rgba(231, 76, 60, 0.3)", line = list(color = "#e74c3c"),
                           text = ~TikTok_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~Nextdoor_Perc, type = "scatter", mode = "none", name = "Nextdoor Spend",
                           stackgroup = "one", fillcolor = "rgba(241, 196, 15, 0.3)", line = list(color = "#f1c40f"),
                           text = ~Nextdoor_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~Affiliate_Perc, type = "scatter", mode = "none", name = "Affiliate Fees",
                           stackgroup = "one", fillcolor = "rgba(52, 73, 94, 0.3)", line = list(color = "#34495e"),
                           text = ~Affiliate_Label, hoverinfo = "text") %>%
                 layout(
                   yaxis = list(title = list(text = ""),tickformat = ".0%", tickfont = list(family = "Montserrat", size = 14)),
                   xaxis = list(title = list(text = ""),tickfont = list(family = "Montserrat", size = 14)),
                   hovermode = "x unified",
                   showlegend = TRUE,
                   legend = list(orientation = "h", x = 0.5, y = 1.1, xanchor = "center",
                                 font = list(family = "Montserrat", size = 14)),
                   margin = list(l = 40, r = 20, t = 60, b = 60),
                   plot_bgcolor = "#ffffff",
                   paper_bgcolor = "#ffffff",
                   font = list(family = "Montserrat")
                 ))
      }
    }
  })
  
  
  
  output$blended_cac_bar_chart <- renderPlotly({
    req(input$selected_date_range)
    req(input$selected_cac_type)
    
    filtered_data <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(
        Date = as.Date(Date),
        Blended_CAC = ifelse(Total_Orders == 0, NA, Total_Spend / Total_Orders),
        wCAC = ifelse(DTC_Orders == 0, NA, Total_DTC_Spend / DTC_Orders),
        aCAC = ifelse(Amazon_Orders == 0, NA, Amazon_Spend / Amazon_Orders),
        appCAC = ifelse(App_Orders == 0, NA, Total_App_Spend / App_Orders)
      )
    
    selected_metric <- input$selected_cac_type
    
    plot_data <- filtered_data %>%
      select(Date, !!selected_metric) %>%
      rename(CAC = !!selected_metric) %>%
      mutate(
        Tooltip = paste0(
          "<span style='font-family: Montserrat;'>",
          "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
          "<b>", gsub("_", " ", selected_metric), ":</b> $", round(CAC, 2),
          "</span>"
        )
      )
    
    p <- ggplot(plot_data, aes(x = Date, y = CAC, text = Tooltip)) +
      geom_col(fill = "#A52A2A", width = 0.6) +
      scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
      scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
      labs(x = NULL, y = NULL) +
      theme_minimal(base_family = "Montserrat") +
      theme(
        plot.title = element_blank(),
        axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
        axis.text.y = element_text(size = 12),
        panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
        plot.background = element_rect(fill = "#ffffff", color = NA),
        panel.background = element_rect(fill = "#ffffff", color = NA)
      )
    
    ggplotly(p, tooltip = "text") %>%
      layout(
        margin = list(l = 40, r = 20, t = 20, b = 60),
        plot_bgcolor = "#ffffff",
        paper_bgcolor = "#ffffff"
      )
  })
  
  
  output$cr_bar_chart <- renderPlotly({
    req(input$selected_date_range)
    
    filtered_data <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(Date = as.Date(Date))
    
    plot_data <- filtered_data %>%
      select(Date, Web_CR) %>%
      mutate(
        CR_Percent = Web_CR * 100,
        Tooltip = paste0(
          "<span style='font-family: Montserrat;'>",
          "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
          "<b>Conversion Rate:</b> ", round(CR_Percent, 2), " %",
          "</span>"
        )
      )
    
    p <- ggplot(plot_data, aes(x = Date, y = CR_Percent, text = Tooltip)) +
      geom_col(fill = "#7b868c", width = 0.6) +
      scale_y_continuous(labels = function(x) paste0(x, "%"), expand = expansion(mult = c(0, 0.1))) +
      scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
      labs(x = "Date", y = "Conversion Rate (%)") +
      theme_minimal(base_family = "Montserrat") +
      theme(
        axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
        axis.text.y = element_text(size = 12),
        panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
        plot.background = element_rect(fill = "#ffffff", color = NA),
        panel.background = element_rect(fill = "#ffffff", color = NA)
      )
    
    ggplotly(p, tooltip = "text") %>%
      layout(
        margin = list(l = 40, r = 20, t = 20, b = 60),
        plot_bgcolor = "#ffffff",
        paper_bgcolor = "#ffffff",
        yaxis = list(title = list(text = "")), 
        xaxis = list(title = list(text = ""))
      )
  })
  
  output$aov_bar_chart <- renderPlotly({
    req(input$selected_date_range)
    req(input$selected_aov_type)
    
    filtered_data <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(Date = as.Date(Date))
    
    if (input$selected_aov_type == "Segmented_AOV") {
      plot_data <- filtered_data %>%
        select(Date, fAOV, rAOV) %>%
        pivot_longer(cols = c(fAOV, rAOV), names_to = "Segment", values_to = "AOV") %>%
        mutate(
          Segment = recode(Segment, fAOV = "First-Time", rAOV = "Returning"),
          Tooltip = paste0(
            "<span style='font-family: Montserrat;'>",
            "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
            "<b>", Segment, " AOV:</b> $", round(AOV, 2),
            "</span>"
          )
        )
      
      p <- ggplot(plot_data, aes(x = Date, y = AOV, fill = Segment, text = Tooltip)) +
        geom_bar(stat = "identity", position = "dodge", width = 0.6) +
        scale_y_continuous(labels = scales::label_dollar()) +
        scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
        scale_fill_manual(values = c("First-Time" = "#3498db", "Returning" = "#2ecc71")) +
        labs(x = NULL, y = NULL) +
        theme_minimal(base_family = "Montserrat") +
        theme(
          axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
          axis.text.y = element_text(size = 12),
          legend.title = element_blank(),
          panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
          plot.background = element_rect(fill = "#ffffff", color = NA),
          panel.background = element_rect(fill = "#ffffff", color = NA)
        )
      
      ggplotly(p, tooltip = "text") %>%
        layout(
          margin = list(l = 40, r = 20, t = 60, b = 60),
          plot_bgcolor = "#ffffff",
          paper_bgcolor = "#ffffff",
          legend = list(
            orientation = "h",
            x = 0.5,
            y = 1.15,
            xanchor = "center",
            font = list(family = "Montserrat", size = 14),
            title = list(text = NULL)  # <-- Hides legend title
          ),
          font = list(family = "Montserrat")
        )
      
    } else {
      selected_metric <- input$selected_aov_type
      plot_data <- filtered_data %>%
        select(Date, !!selected_metric) %>%
        rename(AOV = !!selected_metric) %>%
        mutate(
          Tooltip = paste0(
            "<span style='font-family: Montserrat;'>",
            "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
            "<b>", gsub("_", " ", selected_metric), ":</b> $", round(AOV, 2),
            "</span>"
          )
        )
      
      p <- ggplot(plot_data, aes(x = Date, y = AOV, text = Tooltip)) +
        geom_col(fill = "#3498db", width = 0.6) +
        scale_y_continuous(labels = scales::label_dollar(), expand = expansion(mult = c(0, 0.1))) +
        scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
        labs(x = NULL, y = NULL) +
        theme_minimal(base_family = "Montserrat") +
        theme(
          axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
          axis.text.y = element_text(size = 12),
          panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
          plot.background = element_rect(fill = "#ffffff", color = NA),
          panel.background = element_rect(fill = "#ffffff", color = NA)
        )
      
      ggplotly(p, tooltip = "text") %>%
        layout(
          margin = list(l = 40, r = 20, t = 20, b = 60),
          plot_bgcolor = "#ffffff",
          paper_bgcolor = "#ffffff"
        )
    }
  })
  
  output$customer_split_chart <- renderPlotly({
    req(input$selected_date_range)
    
    plot_data <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(
        Date = as.Date(Date),
        Returning_Percent = Returning_Customers * 100,
        FirstTime_Percent = First_Time_Customers * 100
      )
    
    plot_ly(plot_data, x = ~Date) %>%
      add_trace(y = ~FirstTime_Percent, type = 'bar', name = 'First-Time',
                marker = list(color = 'rgba(52, 152, 219, 0.7)'),
                hoverinfo = 'text',
                text = ~paste0(format(Date, "%b %d, %Y"), "<br>First-Time: ", round(FirstTime_Percent, 1), "%"),
                textposition = "none") %>%
      add_trace(y = ~Returning_Percent, type = 'bar', name = 'Returning',
                marker = list(color = 'rgba(46, 204, 113, 0.7)'),
                hoverinfo = 'text',
                text = ~paste0(format(Date, "%b %d, %Y"), "<br>Returning: ", round(Returning_Percent, 1), "%"),
                textposition = "none") %>%
      layout(
        barmode = 'stack',
        yaxis = list(
          title = "",
          tickvals = seq(0, 100, by = 20),
          ticktext = paste0(seq(0, 100, by = 20), "%"),
          range = c(0, 100),
          tickfont = list(family = "Montserrat", size = 14)
        ),
        
        xaxis = list(
          title = "", tickfont = list(family = "Montserrat", size = 14)
        ),
        hovermode = "x unified",
        showlegend = TRUE,
        legend = list(
          orientation = "h", x = 0.5, y = 1.15, xanchor = "center",
          font = list(family = "Montserrat", size = 14)
        ),
        margin = list(l = 40, r = 20, t = 60, b = 60),
        plot_bgcolor = "#ffffff",
        paper_bgcolor = "#ffffff",
        font = list(family = "Montserrat")
      )
  })
  
  
  
  
  
}


# ---- Run App ----
# Run the application
shinyApp(ui = ui, server = server)
