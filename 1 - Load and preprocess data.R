#Load und rename your data here
#Tidyverse library is required here
#library(tidyverse)
#
#Input CPI-Data
#
#the name dat_joined for your cpi data is required because the function calls the variable dat_joined
#
#dat_joined <- Input your CPI data into dat_joined
#
#dat_joined <- dat_joined %>% 
#  rename(artikelname = "product name column",
#         artikel_id = "article id column",
#         coicop = "coicop column",
#         shop = "shop name column")
#
#
#Input receipt-data, or any data you want to match with the CPI-data
#
#rec <- Input the receipt-data
#
#rec <- rec %>% 
#  rename(article_name = "product name column",
#         article_id = "article id column",
#         shop = "shop name column")
#
#-> If you dont have informations about the shop name or dont want to test store-specific matching
#then create a column called shop an set it to NA. But it is important that you have a column called shop
#in your Dataframe here, becauese the the classification function explicitly checks if we have detected a shop.
#In this case execute the following code:
#
#rec <- rec %>% 
#  mutate(shop = NA)
#
#Do minimal preprocessing of your receipt data
#Remove symbols, that will produce errors on the regex-searches
#
#Symbols to be removed: + | * | ( | ) | ' | [ | ]
#
#rec <- rec %>% 
#  mutate(article_name = str_remove_all(article_name, "[+|*||(|)|']")) %>% 
#  mutate(article_name = str_remove(article_name, "^\\s+")) %>% 
#  mutate(article_name = str_remove_all(article_name, "\\[|\\]"))
#
#After this you can proceed with your preferred preprocessing :)
