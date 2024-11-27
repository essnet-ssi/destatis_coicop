library(tidyverse)
library(stringdist)
library(reticulate)
library(tictoc)
library(data.table)

#Loading the Difflip-Package from Python - reticulate creates a pipeline to python - so we can use the package in R
DIFFLIP <- reticulate::import("difflib")

artname_to_coicop <- function(rec){
  
  #Defining the packages that are nessecary to execute this function in case we want to parallelise this function - in this case every core needs to load
  #the nessecary packages seperatly
  library(dplyr)
  library(stringdist)
  library(reticulate)
  library(tictoc)
  library(data.table)
  DIFFLIP <- reticulate::import("difflib")
  
  unique_shop <- unique(dat_joined$shop)
  
  #Define the length of our output dataframe
  n <- length(rec$article_name)
  
  #Define the output Dataframe - the df should contain the the colums coicop, matching source (str_which, stringsim, str_split, Kein Treffer), 
  #art_name (the article name from the receipt), art_name_match(the article name from our CPI data), shop (the shop we assigned to this receipt), time_to_process 
  #(the run time of the current iteration) and the ocr probability
  df <- data.table(
    coicop = character(length = n),
    matching_source = character(length = n),
    art_name = character(length = n),
    art_name_match = character(length = n),
    shop = character(length = n),
    time_to_process = character(length = n)
  )
  
  #Seq_along korrekt?
  for (i in seq_along(rec$article_name)) {
    
    
    #Save the current values in the variables article_name, article_id and store - before article_name_rec, shop_rec and article_id_rec the renaming should make the variables more plastic
    #The advantage of this should be that from now on you no longer work with an indexed vector, but only with one element from the vector, as it is changed with each iteration.
    article_name_rec <- rec$article_name[i]
    article_id_rec <- rec$article_id[i]
    shop_rec <- rec$shop[i]
    
    #Check if article_name is na - if true then move to the next iteration 
    if(is.na(article_name_rec)){
      next
    }
    
    
    
    
    #tic() starts the time that is stopped for the respective run - the loop reaches the end of a run - when the toc() function is executed,
    #stops the tracked time and is saved. 
    tic()
    
    #Assign the storename  recognized on the receipt to shop
    df$shop[i] <- shop_rec      
    
    #Filter the Scannerdata in case we could determine one ----
    
    if(!is.na(shop_rec) & shop_rec %in% unique_shop){
      
      
      dat_defined <- dat_joined %>% filter(shop == shop_rec)
      
      
    } else{
      
      
      dat_defined <- dat_joined
      
    }
    
    #Artikel-ID-Matching ----
    
    #Test whether an article ID exists - if yes, start with article ID matching
    if(!is.na(article_id_rec)){
      
      #Check if a store exists - If yes, the data is filtered by store - why is this important? Because some article IDs
      #stand for different articles at different stores, e.g. article ID 12234 stands for apple at Aldi and for paper bag at Kaufland
      
      if(!is.na(shop_rec)){
        
        #Test whether the item ID is present in our scanner data - if so, takes the data of interest from the scanner data
        
        if (article_id_rec %in% dat_defined$artikel_id) {
          
          #Determine in which row the item ID that we find on the receipt is in the scanner data
          
          pos <- which(dat_defined$artikel_id == article_id_rec)
          
          #If we have determined the pos and it is not empty, we can take the COICOP
          if(!is_empty(pos) & length(pos) == 1){
            
            coicop_value <- dat_defined$coicop[pos]
            df$art_name_match[i] <- dat_defined$artikelname[pos]
            df$art_name[i] <- article_name_rec
            df$matching_source[i] <- "Artikel-ID-Matching"
            df$coicop[i] <- max(coicop_value)
            
            if(is.na(shop_rec)){
              
              df$matching_source[i] <- "All CPI: Artikel-ID-Matching"
              
            }
            
            
            
          }
        }
      } 
    } 
    #Artikel-ID-Matching-End
    
    #str_which ----
    
    #Make a str_which matching if we could not find a COICOP yet
    
    if(df$coicop[i] == "" ){
      
      #With str_which we search for strings that contain our Receipt Text (Pattern) - i.e. if we search for “Fleichwur.” the function matches 
      #with strings such as “Fleischwurst” “1 Ring Fleischwurst”, “Lyoner Fleischwurst”
      #The positions at which the potential matches are located in the scanner data are now saved in detected_pattern
      detected_pattern <- str_which(dat_defined$artikelname, article_name_rec)
      
      #Check if there are any matches
      if(!is_empty(detected_pattern)){
        
        #Extract all possible matches  
        
        possible_matches <- dat_defined$artikelname[detected_pattern]
        
        #If we only have one potential match then we can directly extract the desired information from the scanner data
        if(length(possible_matches) == 1){
          
          df$art_name_match[i] <- possible_matches
          df$art_name[i] <- article_name_rec
          df$matching_source[i] <- "str_which"
          
          df$coicop[i] <- dat_defined$coicop[detected_pattern]
          
          #If we didnt have detected a store we directly iterate over all CPI data - so we have to asign All CPI:str_which instead of str_which
          if(is.na(shop_rec)){
            
            df$matching_source[i] <- "All CPI: str_which"
            
          }
          
         
          
          
          
        } else{
          
          #If there is more than one potential match, then fuzzy-matching is used to identify the potentially best match
          #Remove all difflip fuzzies? and replace with cosine?
          best_match <- DIFFLIP$get_close_matches(article_name_rec, possible_matches, 1L)
          
          #If the fuzzy matching does not find a meaningful result computationally - another way must be chosen 
          #Fuzzy matching can sometimes fail to produce a result due to a high string length of potential matches
          #Although potentially good matches are available. 
          if(!is_empty(possible_matches) & is_empty(best_match)){
            
            sim_score_best_possible_matches <- stringsim(possible_matches, article_name_rec)
            pos_best_match <- which(sim_score_best_possible_matches == max(sim_score_best_possible_matches))
            #If two matches have the same score, the first one is taken - in this case the strings are usually the same
            best_match <- possible_matches[pos_best_match[1]]
            
          }
          
          if(!is_empty(best_match)){
            
            #Extract the best match from the scannerdata
            pos <- which(dat_defined$artikelname == best_match)
            df$art_name_match[i] <- best_match
            df$art_name[i] <- article_name_rec
            df$matching_source[i] <- "str_which"
            #Best way? 
            coicop <- dat_defined$coicop[pos]
            df$coicop[i] <- max(coicop)
            
            if(is.na(shop_rec)){
              
              df$matching_source[i] <- "All CPI: str_which"
              
            }
            
            
            
            
            
          }
        }
      } 
    } 
    
    #stringsim ----
    
    #when no coicop has been detected do stringsim
    
    if(df$coicop[i] == "" ){
      
      #Create a stringsimiliarity score over all/any filtered scanner data - this step is the one that makes the function “slow”, 
      #because a lot of calculations are performed here. 
      sim_score <- stringsim(dat_defined$artikelname, article_name_rec)
      
      #Extract the positions whose stringsimiliarity is greater than or equal to 0.7
      pos <- which(sim_score >= 0.7)
      
      #Check if there is a match
      
      if(!is_empty(pos)){
        
        #if there was just one match we can save all data
        if(length(pos) == 1){
          
          df$art_name_match[i] <- dat_defined$artikelname[pos]
          df$art_name[i] <- article_name_rec
          df$matching_source[i] <- "stringsim"
          df$coicop[i] <- dat_defined$coicop[pos]
          
          
          if(is.na(shop_rec)){
            
            df$matching_source[i] <- "All CPI: stringsim"
            
          }
          
          
          
          
          
        } else{
          #The mathematically best match (highest osa simscore) is now taken as the best match
          pos_max_sim <- which(sim_score == max(sim_score))
          best_match <- dat_defined$artikelname[pos_max_sim]
          possible_coicop <- dat_defined$coicop[pos_max_sim]
          
          #save results 
          
          df$art_name_match[i] <- best_match[1]
          df$art_name[i] <- article_name_rec
          df$matching_source[i] <- "stringsim"
          df$coicop[i] <- max(possible_coicop)
          
         
          
          if(is.na(shop_rec)){
            
            df$matching_source[i] <- "All CPI: stringsim"
          }
          
          
          
          
        }
      } 
      
      #All CPI ----
      #RUN THROUGH THE ENTIRE LIST - BUT ONLY IF THE DATA WAS PREVIOUSLY FILTERED 
      #If the data was not filtered before, the program basically runs through the same process twice and that takes time
      if(length(dat_joined$artikelname) != length(dat_defined$artikelname) & df$coicop[i] == ""){
        
        #All CPI: str_which ----
        #Filter the scanner data for everything that has not yet been included in the analysis
        dat_defined <- dat_joined %>% filter(!shop == shop_rec)
        
        
        detected_pattern <- str_which(dat_defined$artikelname, article_name_rec)
        #With str_which we search for strings that contain our Receipt Text (Pattern) - i.e. if we search for “Fleichwur.” the function matches 
        #with strings such as “Fleischwurst” “1 Ring Fleischwurst”, “Lyoner Fleischwurst”
        #The positions at which the potential matches are located in the scanner data are now saved in detected pattern
        if(!is_empty(detected_pattern)){
          #Entnehmen der möglichen Matches
          
          possible_matches <- dat_defined$artikelname[detected_pattern]
          #If only one match is available, we can take the information as it is
          if(length(possible_matches) == 1){
            
            df$art_name_match[i] <- possible_matches
            df$art_name[i] <- article_name_rec
            df$matching_source[i] <- "All CPI: str_which"
            df$coicop[i] <- dat_defined$coicop[detected_pattern]
            
           
            
            
          } else{
            
            #If there are more possible matches, fuzzy-matching will be used, to get the best matching cpi-match
            best_match <- DIFFLIP$get_close_matches(article_name_rec, possible_matches, 1L)
            
            if(!is_empty(possible_matches) & is_empty(best_match)){
              
              sim_score_best_possible_matches <- stringsim(possible_matches, article_name_rec)
              pos_best_match <- which(sim_score_best_possible_matches == max(sim_score_best_possible_matches))
              #If two matches have the same score, the first one is taken - in this case the strings are usually the same
              best_match <- possible_matches[pos_best_match[1]]
              
            }
            
            if(!is_empty(best_match)){
              
              #Take the position of the best match - from the scanner data
              pos <- which(dat_defined$artikelname == best_match)
              df$art_name_match[i] <- best_match[1]
              df$art_name[i] <- article_name_rec
              df$matching_source[i] <- "All CPI: str_which"
              coicop <- dat_defined$coicop[pos]
              df$coicop[i] <- max(coicop)
              
              
              
              
              
            }
          }
          
        } 
        
        #All CPI: stringsim ----
        
        #If we have no match so far, then the stringsim method is applied to all scanner data
        if(df$coicop[i] == "" ){
          #Build a stringsimscore across all scanner data
          
          sim_score <- stringsim(dat_defined$artikelname, article_name_rec)
          #Remove the positions that have a stringsimiliarity of greater than or equal to 0.7
          
          pos <- which(sim_score >= 0.7)
          
          #Check if there are any potential matches
          if(!is_empty(pos)){
            
            #If we only have one match, then we can take the information as it is. 
            if(length(pos) == 1){
              
              df$art_name_match[i] <- dat_defined$artikelname[pos]
              df$art_name[i] <- article_name_rec
              df$matching_source[i] <- "All CPI: stringsim"
              df$coicop[i] <- dat_defined$coicop[pos]
              
              
              
              
            } else{
              
              pos_max_sim <- which(sim_score == max(sim_score))
              best_match <- dat_defined$artikelname[pos_max_sim]
              possible_coicop <- dat_defined$coicop[pos_max_sim]
              
              #save results 
              df$art_name_match[i] <- best_match[1]
              df$art_name[i] <- article_name_rec
              df$matching_source[i] <- "All CPI: stringsim"
              df$coicop[i] <- max(possible_coicop)
              
              
              
              
              if(is.na(shop_rec)){
                
                
                df$matching_source[i] <- "All CPI: stringsim"
              }
              
             
              
              
            }
          }
        } 
        #If we have no match so far, then the str_split method is applied to all scanner data
        if(df$coicop[i] == "" ) {
          
          #Str_Split ----
          #The article name is saved in the variable input - commas, periods and hyphens, if present, are then replaced with a 
          #Space character so that the space character can be used as a separator for splitting the string in a later step.
          input <- article_name_rec
          if(str_detect(input, "[^a-zA-Z0-9\\s]")){
            input <- gsub("[^a-zA-Z0-9\\s]", " ", input)
          }
          #Splitting the string into different substrings, which are then stored in the variable test_vec
          test_vec <- str_split(input, " ") %>%  unlist()
          
          #Empty elements are removed from the vector
          if(!is_empty(which(test_vec == ""))){
            test_vec <- test_vec[-which(test_vec == "")]
          }
          
          #All elements from the vector that have a length of less than 2 are removed from the vector
          #because they hinder the matching and mostly do not bring any information gain
          if(!is_empty(which(str_length(test_vec)<= 2))){
            test_vec <- test_vec[-which(str_length(test_vec)<= 2)]
          }
          
          #The first element of the vector is now used to reduce the search corpus with str_which.
          #The positions in the data set are then output first and the reduced corpus is saved in pot_matches 
          #The corresponding coicops are stored in pot_coicop
          pos <- str_which(dat_defined$artikelname, test_vec[1])
          pot_matches <- dat_defined$artikelname[pos]
          pot_coicop <- dat_defined$coicop[pos]
          ####
          #Condition if is_empty(pos)
          ####
          #Define the length or number of substrings that are produced by splitting
          n <- length(test_vec)
          #The for loop now reduces the corpus of possible matches step by step. 
          #The already reduced search corpus is searched again for the jth substring
          for (j in 2:n) {
            if(!is_empty(pot_matches)){
              
              pos <- str_which(pot_matches, test_vec[j])
              pot_matches <- pot_matches[pos]
              pot_coicop <- pot_coicop[pos]
              #When the loop has reached the nth match, it checks whether matches have been found,
              #if the vector pot_matches is not empty, a match can be extracted
              if(n == j){
                if(!is_empty(pot_matches)){
                  
                    
                   
                    #THIS MUST BE EDITED - here the first match is simply taken from the vector of potential matches
                    #this is bad because it is very likely to produce the high rate of miscoding with this method
                    #Here we still have to use a path in which we select the best COICOP, or the really best match
                    
                    #Save results
                    df$art_name[i] <- article_name_rec
                    df$art_name_match[i] <- pot_matches[1]
                    df$matching_source[i] <-  "str_split"
                    df$coicop[i] <- pot_coicop[1]
                    
                   
                  
                    
                    
                 
                }
              }
            }
          }
          
          if(df$art_name_match[i] == ""){
            #No hit can be detected in two ways - if the store was detected and if none was detected
            df$art_name_match[i] <- ""
            df$art_name[i] <- article_name_rec
            df$matching_source[i] <- "Kein Treffer"
            
            
            
          }
        }
      }
    }
    
    
    if(df$coicop[i] == "" ){
      
      input <- article_name_rec
      
      if(str_detect(input, "[,|.|-]")){
        input <- gsub("[,|.|-]", " ", input)
      }
      
      test_vec <- str_split(input, " ") %>%  unlist()
      
      if(!is_empty(which(test_vec == ""))){
        test_vec <- test_vec[-which(test_vec == "")]
      }
      
      
      if(!is_empty(which(str_length(test_vec)<= 2))){
        test_vec <- test_vec[-which(str_length(test_vec)<= 2)]
      }
      
      pos <- str_which(dat_defined$artikelname, test_vec[1])
      pot_matches <- dat_defined$artikelname[pos]
      pot_coicop <- dat_defined$coicop[pos]
      n <- length(test_vec)
      for (j in 2:n) {
      
        if(!is_empty(pot_matches)){
          pos <- str_which(pot_matches, test_vec[j])
          pot_matches <- pot_matches[pos]
          if(n == j){
            if(!is_empty(pot_matches)){
              
                df$art_name[i] <- article_name_rec
                df$art_name_match[i] <- pot_matches[1]
                df$matching_source[i] <-  "str_split"
                df$coicop[i] <- pot_coicop[1]
                
                
                
        }
          
        
              
              
            
          }
        }
      }
    }
    
    
    
    if(df$art_name_match[i] == ""){
      
      df$art_name_match[i] <- ""
      df$art_name[i] <- article_name_rec
      df$matching_source[i] <- "Kein Treffer"
      
      
      
      
      
    }  
    #The stopwatch for the process is stopped here and saved in the variable time_to_process
    df$time_to_process[i] <- str_sub(capture.output(toc()), 1, 5)
    
    
  }
  
  return(df)
  
  
}


#Execute the Function with your preprocessed receipt data
#classification_result_df <- artname_to_coicop(rec = "prepared receipt dataframe")

#rec is required to have the following input-colums  - 
#article_name
#article_id - can be set NA if not available, but not empty "" 
#shop - can be set NA if not avialable - Shop needs to be annotated 1:1 like in the cpi data

