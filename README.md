# destatis_coicop/Pipeline String Matching for Coicop Classification 

  The matching pipeline consists out of two scripts. The fist one - "load and preprocess data" - does three main tasks:
- loading the cpi- and receipt-data
- selecting and renaming the colums, so that the matching function can process the data
  -  The renaming of the columns is very important because the matching function explicitily calls columns from cpi- and the receipt data.
    -  The receipt data needs to be named as follows:
      
        - article_name - product name from the receipt
        - article_id - article id from the receipt
        - shop - shop that has been detected on the receipt
     
    - The cpi data needs to be named as follows:
      
        - artikelname - product name from the cpi data
        - artikel_id - article id from the cpi data
        - shop - shop 
        - coicop - coicop 
  
- removing some special characters, that confuse the regex rules
    -  The preprocessing can be adapted to the requirements of the data as required
 


The second one - "classification function" - is the actual string-matching function. It takes the receipt data as input (in form of a dataframe) and matches each product row with the cpi-data. It returns a dataframe with the input and the (in case it findes one) match and the corresponding coicop. It requires the following packages:

 - R version 4.1.2 (2021-11-01)
 - tidyverse version 2.0.0
 - stringdist version 0.9.10
 - reticulate version 1.32.0
 - tictoc version 1.2
 - data.table version 1.15.4 
 - difflip (python 3.8 package - that is loaded into R)

The scripts can be found in the brance scripts.

Copyright (c) [2024] [Destatis]
Licensed under the EUPL v. 1.2 or later. See the LICENSE file for details.

 
