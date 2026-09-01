
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
sheet_url_apr_2024 <-"https://docs.google.com/spreadsheets/d/1Cop9ei1wbbmUWW3PDJFb5LDJvZpDvGhMY0emn_KkNKU"


# Pull data from Google Sheets and transpose as necessary
apr_dates <- read_sheet(sheet_url_apr_2024, range = "B1:Ae1", col_names = FALSE) %>% 
  t() %>% 
  as.vector() %>% 
  as.Date(format = "%Y-%m-%d")  # adjust format if needed

# Create empty rows with same structure as revenue_data
empty_apr <- as_tibble(matrix(NA, nrow = length(apr_dates), ncol = ncol(revenue_data)))
colnames(empty_apr) <- colnames(revenue_data)

# Fill the Date column
empty_apr$Date <- apr_dates

# Add them before your existing revenue_data
revenue_data <- bind_rows(revenue_data, empty_apr)






summary_data <- read_sheet(sheet_url_apr_2024, sheet = "Summary")
summary_data <- summary_data %>%
  mutate(across(everything(),
                ~ gsub("NULL|^$", "0", .))) %>%       # turn NULL/empty into "0"
  mutate(across(-1, ~ as.numeric(gsub(",", "", .))))  # remove commas + numeric


revenue_data$DTC_Revenue[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[7, -1], use.names = FALSE)))[1:30]
revenue_data$DTC_Hardware[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[8, -1], use.names = FALSE)))[1:30]
revenue_data$DTC_Addons[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[9, -1], use.names = FALSE)))[1:30]
revenue_data$DTC_Merch[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[10, -1], use.names = FALSE)))[1:30]
revenue_data$DTC_Seeds[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[11, -1], use.names = FALSE)))[1:30]
revenue_data$DTC_Subscription[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[12, -1], use.names = FALSE)))[1:30]
revenue_data$DTC_Taxes[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[13, -1], use.names = FALSE)))[1:30]
revenue_data$DTC_Shipping[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[14, -1], use.names = FALSE)))[1:30]

revenue_data$Amazon_Revenue[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[15, -1], use.names = FALSE)))[1:30]
revenue_data$Amazon_Hardware[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[16, -1], use.names = FALSE)))[1:30]
revenue_data$Amazon_Addons[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[17, -1], use.names = FALSE)))[1:30]
revenue_data$Amazon_Tax[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[18, -1], use.names = FALSE)))[1:30]
revenue_data$Amazon_Shipping[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[19, -1], use.names = FALSE)))[1:30]
revenue_data$Amazon_GiftWrap[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[20, -1], use.names = FALSE)))[1:30]

revenue_data$Rachio_Revenue[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[22, -1], use.names = FALSE)))[1:30]
revenue_data$Weatherflow_Revenue[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[26, -1], use.names = FALSE)))[1:30]
revenue_data$Digital_Marketplaces_Revenue[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[21, -1], use.names = FALSE)))[1:30]

revenue_data$Total_Revenue[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[30, -1], use.names = FALSE)))[1:30]
revenue_data$B2B_Revenue[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[41, -1], use.names = FALSE)))[1:30]
revenue_data$BestBuy_Revenue[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[33, -1], use.names = FALSE)))[1:30]
revenue_data$Target_Revenue[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[37, -1], use.names = FALSE)))[1:30]
revenue_data$App_Revenue[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[48, -1], use.names = FALSE)))[1:30]
revenue_data$Google_Store[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[44, -1], use.names = FALSE)))[1:30]
revenue_data$Apple_Store[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[45, -1], use.names = FALSE)))[1:30]
revenue_data$App_Comission[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[46, -1], use.names = FALSE)))[1:30]
revenue_data$App_Tax[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[47, -1], use.names = FALSE)))[1:30]

revenue_data$DTC_Orders[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[51, -1], use.names = FALSE)))[1:30]
revenue_data$DTC_Hardware_Units[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[52, -1], use.names = FALSE)))[1:30]
revenue_data$DTC_Addons_Units[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[53, -1], use.names = FALSE)))[1:30]
revenue_data$DTC_Merch_Units[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[54, -1], use.names = FALSE)))[1:30]
revenue_data$DTC_Seeds_Units[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[55, -1], use.names = FALSE)))[1:30]
revenue_data$DTC_Subscription_Units[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[56, -1], use.names = FALSE)))[1:30]

revenue_data$Amazon_Orders[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[57, -1], use.names = FALSE)))[1:30]
revenue_data$Amazon_Hardware_Units[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[58, -1], use.names = FALSE)))[1:30]
revenue_data$Amazon_Addons_Units[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[59, -1], use.names = FALSE)))[1:30]

revenue_data$Digital_Marketplaces_Orders[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[60, -1], use.names = FALSE)))[1:30]
revenue_data$Rachio_Orders[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[61, -1], use.names = FALSE)))[1:30]
revenue_data$Weatherflow_Orders[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[62, -1], use.names = FALSE)))[1:30]
revenue_data$Total_Orders[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[63, -1], use.names = FALSE)))[1:30]

revenue_data$B2B_Orders[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[68, -1], use.names = FALSE)))[1:30]
revenue_data$BestBuy_Orders[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[66, -1], use.names = FALSE)))[1:30]
revenue_data$Target_Orders[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[67, -1], use.names = FALSE)))[1:30]
revenue_data$App_Orders[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[73, -1], use.names = FALSE)))[1:30]
revenue_data$Google_Store_Orders[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[71, -1], use.names = FALSE)))[1:30]
revenue_data$Apple_Store_Orders[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[72, -1], use.names = FALSE)))[1:30]

revenue_data$Meta_Spend[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[76, -1], use.names = FALSE)))[1:30]
revenue_data$Google_Spend[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[77, -1], use.names = FALSE)))[1:30]
revenue_data$Bing_Spend[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[78, -1], use.names = FALSE)))[1:30]
revenue_data$TikTok_Spend[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[79, -1], use.names = FALSE)))[1:30]
revenue_data$Amazon_Spend[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[80, -1], use.names = FALSE)))[1:30]
revenue_data$Nextdoor_Spend[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[81, -1], use.names = FALSE)))[1:30]
revenue_data$IndieGoGo_Spend[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[82, -1], use.names = FALSE)))[1:30]
revenue_data$Affiliate_Fees[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[83, -1], use.names = FALSE)))[1:30]

revenue_data$Rachio_Fees[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[84, -1], use.names = FALSE)))[1:30]
revenue_data$Weatherflow_Fees[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[85, -1], use.names = FALSE)))[1:30]
revenue_data$Fees[92:121] <- revenue_data$Rachio_Fees[92:121] + revenue_data$Weatherflow_Fees[92:121]

revenue_data$Total_DTC_Spend[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[86, -1], use.names = FALSE)))[1:30]
revenue_data$Total_Spend[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[87, -1], use.names = FALSE)))[1:30]
revenue_data$App_Spend_Meta[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[90, -1], use.names = FALSE)))[1:30]
revenue_data$App_Spend_Apple[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[91, -1], use.names = FALSE)))[1:30]
revenue_data$App_Spend_Google[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[92, -1], use.names = FALSE)))[1:30]
revenue_data$Total_App_Spend[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[93, -1], use.names = FALSE)))[1:30]

revenue_data$Blended_ROAS[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[95, -1], use.names = FALSE)))[1:30]
revenue_data$wROAS[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[96, -1], use.names = FALSE)))[1:30]
revenue_data$aROAS[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[97, -1], use.names = FALSE)))[1:30]
revenue_data$appROAS[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[98, -1], use.names = FALSE)))[1:30]
revenue_data$Blended_SPU[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[100, -1], use.names = FALSE)))[1:30]
revenue_data$wSPU[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[101, -1], use.names = FALSE)))[1:30]
revenue_data$aSPU[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[102, -1], use.names = FALSE)))[1:30]
revenue_data$appSPU[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[103, -1], use.names = FALSE)))[1:30]
revenue_data$Web_CR[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[105, -1], use.names = FALSE)))[1:30]
revenue_data$Web_AOV[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[106, -1], use.names = FALSE)))[1:30]
revenue_data$fAOV[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[107, -1], use.names = FALSE)))[1:30]
revenue_data$rAOV[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[108, -1], use.names = FALSE)))[1:30]
revenue_data$Returning_Customers[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[111, -1], use.names = FALSE)))[1:30]
revenue_data$First_Time_Customers[92:121] <- as.numeric(gsub(",", "", unlist(summary_data[112, -1], use.names = FALSE)))[1:30]





dtc_data <- read_sheet(sheet_url_apr_2024, sheet = "DTC - P&L")
dtc_data <- dtc_data %>%
  mutate(across(everything(),
                ~ gsub("NULL|^$", "0", .))) %>%       # turn NULL/empty into "0"
  mutate(across(-1, ~ as.numeric(gsub(",", "", .))))  # remove commas + numeric

revenue_data$`dtc_SKU 1 - Blue`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[54, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_SKU 2 - Yellow`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[55, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_SKU 3 - Blue w/ Solar`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[56, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_SKU 4 - Yellow w/ Solar`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[57, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_SKU 5 - HBF`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[60, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_SKU 6 - HBF w/ Solar`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[61, -1], use.names = FALSE)))[1:30]

revenue_data$`dtc_Wall Mount`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[64, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_Suet Ball Holder`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[65, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_3-in-1 Nutrition Set - Blue`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[66, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_3-in-1 Nutrition Set - Yellow`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[67, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_Solar Roof Single - Blue`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[68, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_Solar Roof Single - Yellow`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[69, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_Perch Extender - Blue`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[70, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_Perch Extender - Yellow`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[71, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_Solar Roof (HBF)`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[72, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_Housing - only (HBF)`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[73, -1], use.names = FALSE)))[1:30]

revenue_data$`dtc_Seasonal Curation - 8lb`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[76, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_Seasonal Curation - 20lb`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[77, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_Buddy Bites - 8lb`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[78, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_Buddy Bites - 20lb`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[79, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_Snack n' Soar - 8lb`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[80, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_Snack n' Soar - 20lb`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[81, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_Avian Choice - 8lb`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[82, -1], use.names = FALSE)))[1:30]
revenue_data$`dtc_Avian Choice - 20lb`[92:121] <- as.numeric(gsub(",", "", unlist(dtc_data[83, -1], use.names = FALSE)))[1:30]




# ---- amazon data ----
amazon_data <- read_sheet(sheet_url_apr_2024, sheet = "AMAZON - P&L")


revenue_data$`amazon_SKU 1 - Blue`[92:121] <- as.numeric(gsub(",", "", unlist(amazon_data[27, -1], use.names = FALSE)))[1:30]
revenue_data$`amazon_SKU 2 - Yellow`[92:121] <- as.numeric(gsub(",", "", unlist(amazon_data[28, -1], use.names = FALSE)))[1:30]
revenue_data$`amazon_SKU 3 - Blue w/ Solar`[92:121] <- as.numeric(gsub(",", "", unlist(amazon_data[29, -1], use.names = FALSE)))[1:30]
revenue_data$`amazon_SKU 4 - Yellow w/ Solar`[92:121] <- as.numeric(gsub(",", "", unlist(amazon_data[30, -1], use.names = FALSE)))[1:30]
revenue_data$`amazon_Wall Mount`[92:121] <- as.numeric(gsub(",", "", unlist(amazon_data[33, -1], use.names = FALSE)))[1:30]
revenue_data$`amazon_Suet Ball Holder`[92:121] <- as.numeric(gsub(",", "", unlist(amazon_data[34, -1], use.names = FALSE)))[1:30]
revenue_data$`amazon_3-in-1 Nutrition Set - Blue`[92:121] <- as.numeric(gsub(",", "", unlist(amazon_data[35, -1], use.names = FALSE)))[1:30]
revenue_data$`amazon_3-in-1 Nutrition Set - Yellow`[92:121] <- as.numeric(gsub(",", "", unlist(amazon_data[36, -1], use.names = FALSE)))[1:30]
revenue_data$`amazon_Solar Roof Single - Blue`[92:121] <- as.numeric(gsub(",", "", unlist(amazon_data[37, -1], use.names = FALSE)))[1:30]
revenue_data$`amazon_Solar Roof Single - Yellow`[92:121] <- as.numeric(gsub(",", "", unlist(amazon_data[38, -1], use.names = FALSE)))[1:30]
revenue_data$`amazon_Perch Extender - Blue`[92:121] <- as.numeric(gsub(",", "", unlist(amazon_data[39, -1], use.names = FALSE)))[1:30]
revenue_data$`amazon_Perch Extender - Yellow`[92:121] <- as.numeric(gsub(",", "", unlist(amazon_data[40, -1], use.names = FALSE)))[1:30]








# ---- rachio data ----
rachio_data <- read_sheet(sheet_url_apr_2024, sheet = "Digital Marketplaces - P&L")

revenue_data$`rachio_SKU 1 - Blue`[92:121] <- as.numeric(gsub(",", "", unlist(rachio_data[12, -1], use.names = FALSE)))[1:30]
revenue_data$`rachio_SKU 2 - Yellow`[92:121] <- as.numeric(gsub(",", "", unlist(rachio_data[13, -1], use.names = FALSE)))[1:30]
revenue_data$`rachio_SKU 3 - Blue w/ Solar`[92:121] <- as.numeric(gsub(",", "", unlist(rachio_data[14, -1], use.names = FALSE)))[1:30]
revenue_data$`rachio_SKU 4 - Yellow w/ Solar`[92:121] <- as.numeric(gsub(",", "", unlist(rachio_data[15, -1], use.names = FALSE)))[1:30]
revenue_data$`weatherflow_SKU 1 - Blue`[92:121] <- as.numeric(gsub(",", "", unlist(rachio_data[124, -1], use.names = FALSE)))[1:30]
revenue_data$`weatherflow_SKU 2 - Yellow`[92:121] <- as.numeric(gsub(",", "", unlist(rachio_data[125, -1], use.names = FALSE)))[1:30]
revenue_data$`weatherflow_SKU 3 - Blue w/ Solar`[92:121] <- as.numeric(gsub(",", "", unlist(rachio_data[126, -1], use.names = FALSE)))[1:30]
revenue_data$`weatherflow_SKU 4 - Yellow w/ Solar`[92:121] <- as.numeric(gsub(",", "", unlist(rachio_data[127, -1], use.names = FALSE)))[1:30]


app_data <- read_sheet(sheet_url_apr_2024, sheet = "App - P&L")

revenue_data$`apple_yearly_sub`[92:121] <- as.numeric(gsub(",", "", unlist(app_data[14, -1], use.names = FALSE)))[1:30]
revenue_data$`apple_monthly_sub`[92:121] <- as.numeric(gsub(",", "", unlist(app_data[15, -1], use.names = FALSE)))[1:30]
revenue_data$`google_yearly_sub`[92:121] <- as.numeric(gsub(",", "", unlist(app_data[17, -1], use.names = FALSE)))[1:30]
revenue_data$`google_monthly_sub`[92:121] <- as.numeric(gsub(",", "", unlist(app_data[18, -1], use.names = FALSE)))[1:30]

saveRDS(revenue_data, file = "revenue_data.rds")





campaign_notes_df <- data.frame(
  note = c(
    "Increased SKU4 stock by 50",
    "13:20 - SKU1 Amazon button, SKU2 updated to 194 stock, SKU3 back in stock with 393, SKU4 updated to 200 stock. On shop page, we show SKU3 instead of SKU4.",
    "Seeds Launch",
    "11:00 - SKU4 out of stock / Pro Bundle, yellow out of stock",
    "13:27 - 20% off promo ending / Reduced pricing for add-ons",
    "First order with new A/B test prices: #131667 (12:31)",
    "Pricing A/B Test",
    "All yellow units option out of stock (15:37)",
    
    "Valentines Day Sale: 33% off 2nd feeder",
    "Flash Sale: 30% off (MAP Price Model)",
    "A/B Testing - Seeds #1 (First bag free & $26.90 Price)",
    "HBF Pre-Launch (PRO)",
    "Women's Day Offer: 30% off (MAP Price Model)",
    "HBF Main Launch",
    
    "A/B Testing - Seeds #2 (First bag free & $14.90 Price)",
    "HBF Price Increase: HBF - $289; HBF w/ Solar - $359",
    "Meta Advertising Stopped",
    "BestBuy - Deal of the day",
    "A/B Testing - PRO #1",
    "PR - WSJ",
    "Patagonia Checkout Live",
    "HBF Shipping from June to August",
    
    "PRO Subscription Test",
    "Seeds Test - $29,90",
    "Awareness Campaigns",
    "Referral System - 10k users",
    "Wirecutter Newsletter feature",
    "Amazon SKU3 listing removed",
    "Start conversion campaign on Meta",
    "A/B Testing - PRO + Seeds"
  ),
  start = as.Date(c("2024-01-07",
                    "2024-01-08",
                    "2024-01-15",
                    "2024-01-19",
                    "2024-01-19",
                    "2024-01-24",
                    "2024-01-24",
                    "2024-01-31",
                    
                    "2024-02-05", 
                    "2024-02-15",
                    "2024-02-22",
                    "2024-02-28", 
                    "2024-02-29", 
                    "2024-02-29",
                    
                    "2024-03-08",
                    "2024-03-11",
                    "2024-03-15",
                    "2024-03-19",
                    "2024-03-19",
                    "2024-03-22",
                    "2024-03-25",
                    "2024-03-27",
                    
                    "2024-04-01",
                    "2024-04-15",
                    "2024-04-15",
                    "2024-04-24",
                    "2024-04-28",
                    "2024-04-28",
                    "2024-04-29",
                    "2024-04-29")),
  
  end = as.Date(c("2024-01-07",
                  "2024-01-08",
                  "2024-01-15",
                  "2024-01-19",
                  "2024-01-19",
                  "2024-01-24",
                  "2024-01-31",
                  "2024-01-31",
                  
                  "2024-02-14", 
                  "2024-02-27",
                  "2024-03-07",
                  "2024-02-28", 
                  "2024-03-11", 
                  "2024-03-01",
                  
                  "2024-03-18",
                  "2024-03-11",
                  "2024-03-15",
                  "2024-03-19",
                  "2024-03-31",
                  "2024-03-22",
                  "2024-03-25",
                  "2024-03-27",
                  
                  "2024-04-14",
                  "2024-04-29",
                  "2024-04-29",
                  "2024-04-24",
                  "2024-04-28",
                  "2024-04-28",
                  "2024-04-29",
                  "2024-04-30")),
  stringsAsFactors = FALSE
)

# 1. Read the Post-purchase survey sheet
pps_data <- read_sheet(sheet_url_apr_2024, sheet = "PP - Data")

# Create empty rows with same structure as revenue_data
empty_apr <- as_tibble(matrix(NA, nrow = length(apr_dates), ncol = ncol(survey_data)))
colnames(empty_apr) <- colnames(survey_data)

# Fill the Date column
empty_apr$Date <- apr_dates

# Add them before your existing revenue_data
survey_data <- bind_rows(survey_data,empty_apr)

survey_data[92:100, 2]<- as.numeric(gsub(",", "", unlist(pps_data[1, -1], use.names = FALSE)))[1:9]
survey_data[92:100, 3]<- as.numeric(gsub(",", "", unlist(pps_data[2, -1], use.names = FALSE)))[1:9]
survey_data[92:100, 4]<- as.numeric(gsub(",", "", unlist(pps_data[3, -1], use.names = FALSE)))[1:9]
survey_data[92:100, 5]<- as.numeric(gsub(",", "", unlist(pps_data[4, -1], use.names = FALSE)))[1:9]
survey_data[92:100, 6]<- as.numeric(gsub(",", "", unlist(pps_data[5, -1], use.names = FALSE)))[1:9]
survey_data[92:100, 7]<- as.numeric(gsub(",", "", unlist(pps_data[6, -1], use.names = FALSE)))[1:9]
survey_data[92:100, 8]<- as.numeric(gsub(",", "", unlist(pps_data[7, -1], use.names = FALSE)))[1:9]
survey_data[92:100, 9]<- as.numeric(gsub(",", "", unlist(pps_data[8, -1], use.names = FALSE)))[1:9]
survey_data[92:100, 10]<- as.numeric(gsub(",", "", unlist(pps_data[22, -1], use.names = FALSE)))[1:9]
survey_data[92:100, 11]<- as.numeric(gsub(",", "", unlist(pps_data[23, -1], use.names = FALSE)))[1:9]
survey_data[92:100, 12]<- as.numeric(gsub(",", "", unlist(pps_data[24, -1], use.names = FALSE)))[1:9]
survey_data[92:100, 13]<- as.numeric(gsub(",", "", unlist(pps_data[35, -1], use.names = FALSE)))[1:9]
survey_data[92:100, 14]<- as.numeric(gsub(",", "", unlist(pps_data[41, -1], use.names = FALSE)))[1:9]
survey_data[92:100, 15]<- as.numeric(gsub(",", "", unlist(pps_data[47, -1], use.names = FALSE)))[1:9]
survey_data[92:100, 16]<- as.numeric(gsub(",", "", unlist(pps_data[53, -1], use.names = FALSE)))[1:9]


survey_data$`q4_New customer` <- 0
survey_data$`q4_Existing customer` <- 0

survey_data$`Nq1_Facebook / Instagram` <- 0
survey_data$`Nq1_Friends / Family` <- 0
survey_data$`Nq1_TikTok` <- 0
survey_data$`Nq1_TV / Radio` <- 0
survey_data$`Nq1_Blog / Article` <- 0
survey_data$`Nq1_Reddit` <- 0
survey_data$`Nq1_Google, Youtube` <- 0
survey_data$`Nq1_Yahoo, Bing` <- 0

survey_data$`Nq2_I saw an ad` <- 0
survey_data$`Nq2_I saw a post about Bird Buddy on my friend's feed` <- 0
survey_data$`Nq2_I saw an organic post from Bird Buddy` <- 0

survey_data$`Nq3_Just me` <- 0
survey_data$`Nq3_My parents` <- 0
survey_data$`Nq3_Spouse` <- 0
survey_data$`Nq3_I will use with my family` <- 0

survey_data$`Oq1_Facebook / Instagram` <- 0
survey_data$`Oq1_Friends / Family` <- 0
survey_data$`Oq1_TikTok` <- 0
survey_data$`Oq1_TV / Radio` <- 0
survey_data$`Oq1_Blog / Article` <- 0
survey_data$`Oq1_Reddit` <- 0
survey_data$`Oq1_Google, Youtube` <- 0
survey_data$`Oq1_Yahoo, Bing` <- 0

survey_data$`Oq2_I saw an ad` <- 0
survey_data$`Oq2_I saw a post about Bird Buddy on my friend's feed` <- 0
survey_data$`Oq2_I saw an organic post from Bird Buddy` <- 0

survey_data$`Oq3_Just me` <- 0
survey_data$`Oq3_My parents` <- 0
survey_data$`Oq3_Spouse` <- 0
survey_data$`Oq3_I will use with my family` <- 0

# 1. Read the Post-purchase survey sheet
pps2_data <- read_sheet(sheet_url_apr_2024, sheet = "New PP - Data")
survey_data[101:121, 17]<- as.numeric(gsub(",", "", unlist(pps2_data[2, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 18]<- as.numeric(gsub(",", "", unlist(pps2_data[3, -1], use.names = FALSE)))[10:30]

survey_data[101:121, 19]<- as.numeric(gsub(",", "", unlist(pps2_data[23, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 20]<- as.numeric(gsub(",", "", unlist(pps2_data[24, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 21]<- as.numeric(gsub(",", "", unlist(pps2_data[25, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 22]<- as.numeric(gsub(",", "", unlist(pps2_data[26, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 23]<- as.numeric(gsub(",", "", unlist(pps2_data[27, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 24]<- as.numeric(gsub(",", "", unlist(pps2_data[28, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 25]<- as.numeric(gsub(",", "", unlist(pps2_data[29, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 26]<- as.numeric(gsub(",", "", unlist(pps2_data[30, -1], use.names = FALSE)))[10:30]

survey_data[101:121, 27]<- as.numeric(gsub(",", "", unlist(pps2_data[42, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 28]<- as.numeric(gsub(",", "", unlist(pps2_data[43, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 29]<- as.numeric(gsub(",", "", unlist(pps2_data[44, -1], use.names = FALSE)))[10:30]

survey_data[101:121, 30]<- as.numeric(gsub(",", "", unlist(pps2_data[12, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 31]<- as.numeric(gsub(",", "", unlist(pps2_data[13, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 32]<- as.numeric(gsub(",", "", unlist(pps2_data[14, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 33]<- as.numeric(gsub(",", "", unlist(pps2_data[15, -1], use.names = FALSE)))[10:30]


survey_data[101:121, 34]<- as.numeric(gsub(",", "", unlist(pps2_data[65, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 35]<- as.numeric(gsub(",", "", unlist(pps2_data[66, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 36]<- as.numeric(gsub(",", "", unlist(pps2_data[67, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 37]<- as.numeric(gsub(",", "", unlist(pps2_data[68, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 38]<- as.numeric(gsub(",", "", unlist(pps2_data[69, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 39]<- as.numeric(gsub(",", "", unlist(pps2_data[70, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 40]<- as.numeric(gsub(",", "", unlist(pps2_data[71, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 41]<- as.numeric(gsub(",", "", unlist(pps2_data[72, -1], use.names = FALSE)))[10:30]

survey_data[101:121, 42]<- as.numeric(gsub(",", "", unlist(pps2_data[84, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 43]<- as.numeric(gsub(",", "", unlist(pps2_data[85, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 44]<- as.numeric(gsub(",", "", unlist(pps2_data[86, -1], use.names = FALSE)))[10:30]

survey_data[101:121, 45]<- as.numeric(gsub(",", "", unlist(pps2_data[54, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 46]<- as.numeric(gsub(",", "", unlist(pps2_data[55, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 47]<- as.numeric(gsub(",", "", unlist(pps2_data[56, -1], use.names = FALSE)))[10:30]
survey_data[101:121, 48]<- as.numeric(gsub(",", "", unlist(pps2_data[57, -1], use.names = FALSE)))[10:30]

survey_data[101:121, 2]<-survey_data[101:121, 19]+survey_data[101:121, 34]
survey_data[101:121, 3]<-survey_data[101:121, 20]+survey_data[101:121, 35]
survey_data[101:121, 4]<-survey_data[101:121, 21]+survey_data[101:121, 36]
survey_data[101:121, 5]<-survey_data[101:121, 22]+survey_data[101:121, 37]
survey_data[101:121, 6]<-survey_data[101:121, 23]+survey_data[101:121, 38]
survey_data[101:121, 7]<-survey_data[101:121, 24]+survey_data[101:121, 39]
survey_data[101:121, 8]<-survey_data[101:121, 25]+survey_data[101:121, 40]
survey_data[101:121, 9]<-survey_data[101:121, 26]+survey_data[101:121, 41]

survey_data[101:121, 10]<-survey_data[101:121, 27]+survey_data[101:121, 42]
survey_data[101:121, 11]<-survey_data[101:121, 28]+survey_data[101:121, 43]
survey_data[101:121, 12]<-survey_data[101:121, 29]+survey_data[101:121, 44]

survey_data[101:121, 13]<-survey_data[101:121, 30]+survey_data[101:121, 45]
survey_data[101:121, 14]<-survey_data[101:121, 31]+survey_data[101:121, 46]
survey_data[101:121, 15]<-survey_data[101:121, 32]+survey_data[101:121, 47]
survey_data[101:121, 16]<-survey_data[101:121, 33]+survey_data[101:121, 48]
survey_data[is.na(survey_data)] <- 0

saveRDS(campaign_notes_df, file = "campaign_notes_df.rds")
saveRDS(revenue_data, file = "revenue_data.rds")
saveRDS(survey_data, file = "survey_data.rds")

