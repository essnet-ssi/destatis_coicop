# destatis_coicop/Pipeline String Matching for Coicop Classification 

### Table of Content

- [Scripts](#scripts)
  - [load_and_preprocess_data.R](#load_and_preprocess_data.R)
  - [classification_function.R](#classification_function.R)
- [Matching-Algorithm](#Matching-Algorithm)
  - [article_id_matching](#article_id_matching)
  - [str_which](#str_which)
  - [stringsim](#stringsim)
  - [str_split](#str_split)
- [Flowchart](#Flowchart)



## Scripts

The matching pipeline consists out of two scripts `load_and_preprocess_data.R` and `classification_function.R`.

### `load_and_preprocess_data.R`

  This Script servers three main purposes:
- loading the cpi- and receipt-data
- selecting and renaming the colums, so that the matching function can process the data
  -  The renaming of the columns is very important because the matching function explicitily calls columns from cpi- and the receipt data.
    -  The receipt data needs to be named as follows:
      
        - `article_name` - product name from the receipt
        - `article_id` - article id from the receipt
        - `shop` - shop that has been detected on the receipt
     
    - The cpi data needs to be named as follows:
      
        - `artikelname` - product name from the cpi data
        - `artikel_id` - article id from the cpi data
        - `shop` - shop 
        - `coicop` - coicop 
  
- removing some special characters, that confuse the regex rules
    -  The preprocessing can be adapted to the requirements of the data as required
 

### `classification_function.R`

This script defines the function that performes the stringmatching in combination with the ML-Classification. It takes the receipt data as input (in form of a dataframe) and matches each product row with the cpi-data. In case string matching doesn't result in a match a fasttext model will be used to classify the given product row. It returns a dataframe with the input and the (in case it findes one) match and the corresponding coicop. It requires the following packages:

 - `R` version 4.1.2 (2021-11-01)
 - `tidyverse` version 2.0.0
 - `stringdist` version 0.9.10
 - `reticulate` version 1.32.0
 - `tictoc` version 1.2
 - `data.table` version 1.15.4 
 - `difflip` (python 3.8 package - that is loaded into R)


## Matching-Algorithm


The matching function follows the concept displayed in this Plot. There are three main step that are hierachially ordered:

![image](https://github.com/user-attachments/assets/68ce4bd2-7fa5-431e-857e-a1b1c31386aa)


In case we detect a shop on the current receipt we apply the matching over shop-filtered cpi-data. If there is no match on the shop-filtered corpus, we go back to the first step and apply the matching over the complete cpi-corpus. In case we couldnt detect a shop, we apply the matching dirtectly over the complete cpi corpus. The diffent substeps work like displayed in the following flowcharts:

### article_id_matching

- In case we can detect an article-id for a given product on a receipt we can performe article-id matching. Scanner data deliveries from retail stores usually contain some type of product ID. In most cases this information is irrelevant, however, selected retail stores print the product ID on their receipts. One such example is the supermarket chain Aldi in Germany. Therefore, if the possibility is given, the most straightforward way of matching product descriptions is by means of such a product ID. This method is highly accurate and relies on the correct extraction of product IDs from the receipt.

### str_which:

![image](https://github.com/user-attachments/assets/5a6e389b-2eb1-46ca-a3aa-d1bb6e984e2a)


 - The str_which function searches the corpus for strings that are a 1:1 match with the given input or contain the input as a substring. The function returns the position of the match in the matching corpus. Let’s assume we’re looking for the string “apple spritzer”. The function would, for example, output the position of the strings “apple spritzer”, “apple spritzer 6x1.5l” or “apple spritzer 6x0.5l” as potential matches. With the function str_which output positions of the potential matches we can directly extract the corresponding COICOPs from the data. This gives us three potential matches and accordingly three potential COICOPs that we can assign to the string entered.In order to identify the best possible match, the potential matches are now matched again with the originally given input using fuzzy matching. The fuzzy matching is performed via a Python interface using the Difflip package and the get_close_matches function included therein. In the example case, the 1:1 match is identified as the best match. However, there are often cases where no 1:1 match is found, then fuzzy matching identifies the best match based on the string similiarities of the potential matches to the given input.



### stringsim:

![image](https://github.com/user-attachments/assets/5c1f4616-5e15-4adb-aeec-3124e10bc6d6)


 - The stringsim function is used to calculate a value for the string similarity to the given input (product name on the receipt) for each product name in the search corpus. Then all positions in the vector of similarity scores that have a score greater than or equal to 0.7 are extracted using which(sim_score >= 0.7). The value 0.7 is not a generally valid limit value that was taken from the literature or other sources, it emerged from experience with the data. Strings that have a similarity of greater than or equal to 0.7 are usually meaningfully matching strings. Based on the positions determined in the matching corpus, potential matches and potential COICOPs can now be identified. Based on the potential matches identified here, fuzzy matching is again carried out, analogous to the procedure for str_which, in order to identify the best possible match and, accordingly, the best possible COICOP. The string similiarity is calculated using the OSA - Optimal String Alignment method. The similarity of the strings (a, b) is determined by the minimum number of processing steps required to transform the string b into the string a. Interchanging, replacing and deleting characters are permitted. The stringsim function belongs to the stringdist package. It offers various methods for determining similarity. The Metohde OSA was not deliberately chosen, it is the default method of this function.
   

### str_split: 

![image](https://github.com/user-attachments/assets/e6c2408e-a7a0-4d9b-8410-af7515835e49)


  - The procedure for the str_split method is similar to the procedure for str_which, but there is another process upstream of it. The first step here is to tokenize the product description of the receipt (at the “word level”) or split it into different substrings. The string is split based on various characteristics. These are: spaces, (double) periods, commas, dashes or minus signs. In addition, substrings that have a string length of less than or equal to 2 are excluded, as these usually do not lead to any gain in knowledge or are even the reason for a missing match. A string such as “rücker Käse Natur” becomes three substrings “rücker”, “Käse” and “Natur”. Starting with the first substring, the search corpus is now gradually reduced. With str_which() all strings are determined that contain the first substring, in the example “rücker”. The already reduced search corpus is then reduced again with str_which by removing all strings that contain the second substring, in the example “Käse”. This procedure is repeated until the nth substring. When the nth substring is reached, we get a vector with potential matches from which we can extract a meaningful COICOP. So far, the first element in the vector of potential matches has been used as the match. A way needs to be added here that identifies the best match.

## Flowchart

![Flowchart Template (8)](https://github.com/user-attachments/assets/19e1be52-f416-4fd0-bb9b-88951ef215b9)



Copyright (c) [2024] [Destatis]
Licensed under the EUPL v. 1.2 or later. See the LICENSE file for details.

 

 
