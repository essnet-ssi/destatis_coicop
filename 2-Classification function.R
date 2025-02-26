# this script describes the string-matching-function in R

artname_to_coicop_reduced <- function(rec){
  
  # defining the packages that are necessary to execute this function in case we want to run this function in parallel
  # in this case every core needs to load the necessary packages separately
  # dplyr is used for basic data engineering tasks
  # reticulate is used to run Python functionality inside R
  # stringdist is used for calculating string distance metrices
  # tictoc is used for measuring time
  # data.table is used to have faster functionalities for dataframe (i.e. tables)
  library(dplyr)
  library(stringdist)
  library(reticulate)
  library(tictoc)
  library(data.table)
  # difflib from Python is used for fuzzy matching
  difflib_from_python <- reticulate::import("difflib")
  
  # saving all unique shops from VPI data for store-specific matching if possible
  unique_shop <- unique(dat_joined$shop)
  
  # defining the length of our output dataframe
  n <- length(rec$article_name)
  
  # defining the empty output Dataframe - the df should contain the the column coicop, string matching source (str_which, stringsim, str_split, no_match_found), 
  # art_name (the article name from the receipt), art_name_match(the article name from our CPI data), shop (the shop that was assigned to this receipt), time_to_process 
  # (the run time of the current iteration) and the optical character recognition (ocr) probability
  df <- data.frame(
    coicop = character(length = n),
    matching_source = character(length = n),
    # article name from the receipt
    art_name = character(length = n),
    art_name_match = character(length = n),
    # shop name from receipt
    shop = character(length = n),
    time_to_process = character(length = n)
  )
  
  # this function is used to process string splitting results - any strings resulting from string splitting with a length of 2 characters or less are discarded
  str_split_recursiv <- function(string, df){
    
    # replacing non-alphanumeric characters with whitespace for splitting at this whitespace
    tokenized_string <- gsub("[^a-zA-Z0-99äöüÄÖÜß\\s]", " ", string) %>%
      str_split(" ") %>%
      unlist()
    if(any(str_length(tokenized_string) <= 2)){
      tokenized_string <- tokenized_string[-which(str_length(tokenized_string) <= 2)]
    }
    
    # in case of many possible matches, this function returns the match with the highest cosine similarity
    filter_df <- function(vec, df){
      n <- length(vec)
      if(n != 0){
        
        if(nrow(df) == 0){
          return(NULL)
        }
        
        df <- df %>% filter(str_detect(artikelname, vec[n]))
        
        filter_df(vec[-n], df)
      } else{
        pos_max <- which.max(stringsim(string, df$artikelname, method = "cosine"))
        return(list(coicop = df$coicop[pos_max], artikelname = df$artikelname[pos_max]))
      }
    }
    
    filter_df(tokenized_string, dat_joined)
  }
  
  
  for (i in seq_along(rec$article_name)) {
    
    # saving the current values in their respective variables article_name_rec, article_id_rec and store_rec
    #The advantage of this should be that from now on you no longer work with an indexed vector, but only with one element from the vector, as it is changed with each iteration
    article_name_rec <- rec$article_name[i]
    article_id_rec <- rec$article_id[i]
    shop_rec <- rec$shop[i]
    
    # checking if article_name is na - if true then move to the next iteration 
    if(is.na(article_name_rec)){
      next
    }

    #tic() starts the time that is stopped for the respective run - the loop reaches the end of a run - when the toc() function is executed, it stops and saves the tracked time
    tic()
    # assigning the store name recognized on the receipt to shop
    df$shop[i] <- shop_rec      
    
    # filtering scannerdata in case we could determine a shop ----
    if(!is.na(shop_rec) & shop_rec %in% unique_shop){
      
      # this is used for store specific matching
      dat_defined <- dat_joined %>% filter(shop == shop_rec)
      
    } else{
      
            dat_defined <- dat_joined
      
    }
    
    # Artikel-ID-Matching ----
    
    # test whether an article ID exists - if yes, start with article ID matching
    if(!is.na(article_id_rec)){
      
      #Check if a store exists - If yes, the data is filtered by store - why is this important? - Because some article IDs stand for different articles at different stores
      # e.g. article ID 12234 stands for apple at Aldi and for paper bag at Kaufland --> therefore, one article ID can appear in different shops
      if(!is.na(shop_rec)){
        
        # testing whether the item ID is present in our scanner data - if so, takes the data of interest from the scanner data
        if (article_id_rec %in% dat_defined$artikel_id) {
          
          # determining in which row the item ID that we find on the receipt is in the scanner data
          # the which function saves an index which can be saved as a position
          pos <- which(dat_defined$artikel_id == article_id_rec)
          
          # if we have determined the pos and it is not empty, we can take the COICOP
          # we check if the article ID appears only once
          if(!is_empty(pos) & length(pos) == 1){
            
            #coicop_value <- dat_defined$coicop[pos]
            df$art_name_match[i] <- dat_defined$artikelname[pos]
            df$art_name[i] <- article_name_rec
            df$matching_source[i] <- "Artikel-ID-Matching"
            df$coicop[i] <- dat_defined$coicop[pos]#max(coicop_value)
          }
        }
      } 
    } 
    # enf of article-ID-matching
    
    #str_which ----
    
    #Make a str_which matching if we could not find a COICOP yet
    if(df$coicop[i] == "" ){
      
      # with str_which we search for strings that contain our receipt text (pattern)
      # i.e. if we search for “Fleichwur.” the function matches strings such as “Fleischwurst” “1 Ring Fleischwurst”, “Lyoner Fleischwurst”
      # The positions at which the potential matches are located in the scanner data get saved in detected_pattern
      detected_pattern <- str_which(dat_defined$artikelname, fixed(article_name_rec))
      
      #Check if there are any matches
      if(!is_empty(detected_pattern)){
        
        # extracting all possible matches  
        possible_matches <- dat_defined$artikelname[detected_pattern]
        
        # if we only have one potential match then we can directly extract the desired information from the scanner data
        if(length(possible_matches) == 1){
          
          df$art_name_match[i] <- possible_matches
          df$art_name[i] <- article_name_rec
          df$matching_source[i] <- "str_which"
          
          df$coicop[i] <- dat_defined$coicop[detected_pattern]
          
          #If we didnt have detected a store we directly iterate over all CPI data - so we have to assign All CPI:str_which instead of str_which
          if(is.na(shop_rec)){
            
            df$matching_source[i] <- "All CPI: str_which"
            
          }
          
          
          
          
          
        } else{
          
          #If there is more than one potential match, then fuzzy-matching is used to identify the potentially best match

          #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
          # ! the order can matter with difflib, it might not matter with cosine similarity
          # example: when looking for "bio apfelschorle", we get "bio apfelschorle"
          # when looking for "apfelschorle bio", we might get "apfelschorle rot"
          # --> therefore, tis algorithm might be changed in the future
          # another possibility: stringsim(possible_matches, true_article_name_from_receipt, method = "cosine")
          # -> this could be used for the case IF THERE ALREADY A FEW POSSIBLE MATCHES
          # (without possible matches, cosine similarity might produce lots of false positives)
          #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
          
          # fuzzy-matching from reticulate
          best_match <- difflib_from_python$get_close_matches(article_name_rec, possible_matches, 1L)
          
          #If the fuzzy matching does not find a meaningful result computationally - another way must be chosen 
          # fuzzy matching can sometimes fail to produce a result due to a high string length of potential matches
          # although potentially good matches are available
          
          # the fuzzy matching might give an empty list
          if(!is_empty(possible_matches) & is_empty(best_match)){
            # for this case, another method is used for calculating again
            # https://cran.r-project.org/web/packages/stringdist/stringdist.pdf - default for stringsim is optimal string alignment
            sim_score_best_possible_matches <- stringsim(possible_matches, article_name_rec)
            pos_best_match <- which(sim_score_best_possible_matches == max(sim_score_best_possible_matches))
            #If two matches have the same score, the first one is taken - in this case the strings are usually the same
            best_match <- possible_matches[pos_best_match[1]]
            
          }
          
          if(!is_empty(best_match)){
            
            # extracting the best match from the scannerdata
            pos <- which(dat_defined$artikelname == best_match)
            df$art_name_match[i] <- best_match
            df$art_name[i] <- article_name_rec
            df$matching_source[i] <- "str_which"
            coicop <- dat_defined$coicop[pos]
            df$coicop[i] <- max(coicop)
            
            if(is.na(shop_rec)){
              
              df$matching_source[i] <- "All CPI: str_which"
              
            }
            
            
          }
        }
      } 
    } 
    
    # stringsim ----
    
    # when no coicop has been detected yet, the stringsim algorithm is the next step in the matching pipeline
    
    if(df$coicop[i] == "" ){
      
      # creating a stringsimiliarity score over all/any filtered scanner data - this step is the one that makes the function “slow”, 
      #because a lot of calculations are performed here
      # dat_sc is the source of the scanner data
      # dat_defined is the joined data with information read by optical character recognition
      # article_name_red represents the value at position i
      
      #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      # to make this quicker, dat_defined$artikelname could be filtered - all strings 20 % longer or shorter than article_name_rec would eventually be a bad match 
      #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      #
      #
      stringlength_article_borders <- c(round(str_length(article_name_rec)*0.7), round(str_length(article_name_rec)*1.3))
      dat_defined_reduced <- dat_defined %>%
        filter(stringlength > stringlength_article_borders[1] & stringlength < stringlength_article_borders[2])
      #
      #
      #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      sim_score <- stringsim(dat_defined_reduced$artikelname, article_name_rec)
      
      # extracting the positions whose string similiarity is greater than or equal to 0.7
      pos <- which(sim_score >= 0.7)
      
      # checking if there is a match
      
      if(!is_empty(pos)){
        
        #if there was just one match we can save all data
        if(length(pos) == 1){
          
          df$art_name_match[i] <- dat_defined_reduced$artikelname[pos]
          df$art_name[i] <- article_name_rec
          df$matching_source[i] <- "stringsim"
          df$coicop[i] <- dat_defined_reduced$coicop[pos]
          
          
          if(is.na(shop_rec)){
            
            df$matching_source[i] <- "All CPI: stringsim"
            
          }
          
          
          
          
          
        } else{
          #The mathematically best match (highest osa simscore) is now taken as the best match
          pos_max_sim <- which.max(sim_score)
          best_match <- dat_defined_reduced$artikelname[pos_max_sim]
          possible_coicop <- dat_defined_reduced$coicop[pos_max_sim]
          
          #saving the results 
          df$art_name_match[i] <- best_match[1]
          df$art_name[i] <- article_name_rec
          df$matching_source[i] <- "stringsim"
          df$coicop[i] <- max(possible_coicop)
       
          if(is.na(shop_rec)){
            
            df$matching_source[i] <- "All CPI: stringsim"
          }
          
        }
      } 
      
      remove(dat_defined_reduced)
      
      # all CPI ----
      # RUNNNING THROUGH THE ENTIRE LIST - BUT ONLY IF THE DATA WAS PREVIOUSLY FILTERED 
      # if the data was not filtered before, the program basically runs through the same process twice and that takes time
      # if dataframes have not the same length, this means that data has been filtered by a shop before
      #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      # the following is basically a repetition of the core structure above and might be refactored for a custom function
      #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      
      if(length(dat_joined$artikelname) != length(dat_defined$artikelname) & df$coicop[i] == ""){
        
        # All CPI: str_which ----
        # filtering the scanner data for everything that has not yet been included in the analysis
        # filtering for everything except the data that was seen already
        dat_defined <- dat_joined %>% filter(!shop == shop_rec)
        #hier fixed string einsetzen.
        detected_pattern <- str_which(dat_defined$artikelname, fixed(article_name_rec))

        if(!is_empty(detected_pattern)){

          possible_matches <- dat_defined$artikelname[detected_pattern]
          #If only one match is available, we can take the information as it is
          if(length(possible_matches) == 1){
            
            df$art_name_match[i] <- possible_matches
            df$art_name[i] <- article_name_rec
            df$matching_source[i] <- "All CPI: str_which"
            df$coicop[i] <- dat_defined$coicop[detected_pattern]
     
          } else{
            
            # if there are more possible matches, fuzzy-matching is being used to get the best matching cpi-match
            best_match <- difflib_from_python$get_close_matches(article_name_rec, possible_matches, 1L)
            
            if(!is_empty(possible_matches) & is_empty(best_match)){
              
              sim_score_best_possible_matches <- stringsim(possible_matches, article_name_rec)
              pos_best_match <- which(sim_score_best_possible_matches == max(sim_score_best_possible_matches))
              # if two matches have the same score, the first one is taken - in this case the strings are usually the same
              best_match <- possible_matches[pos_best_match[1]]
              
            }
            
            if(!is_empty(best_match)){
              
              # taking the position of the best match from the scanner data
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
          # building a stringsim-score across all scanner data
          stringlength_article_borders <- c(round(str_length(article_name_rec)*0.7), round(str_length(article_name_rec)*1.3))
          dat_defined_reduced <- dat_defined %>%
            filter(stringlength > stringlength_article_borders[1] & stringlength < stringlength_article_borders[2])
          
          sim_score <- stringsim(dat_defined_reduced$artikelname, article_name_rec)
          # keeping the positions that have a string similiarity of greater than or equal to 0.7
  
          pos <- which(sim_score >= 0.7)
          
          # check if there are any potential matches
          if(!is_empty(pos)){
            
            #If we only have one match, then we can take the information as it is. 
            if(length(pos) == 1){
              
              df$art_name_match[i] <- dat_defined_reduced$artikelname[pos]
              df$art_name[i] <- article_name_rec
              df$matching_source[i] <- "All CPI: stringsim"
              df$coicop[i] <- dat_defined_reduced$coicop[pos]
           
            } else{
              
              pos_max_sim <- which.max(sim_score)
              best_match <- dat_defined_reduced$artikelname[pos_max_sim]
              possible_coicop <- dat_defined_reduced$coicop[pos_max_sim]
              
              # saving results 
              df$art_name_match[i] <- best_match[1]
              df$art_name[i] <- article_name_rec
              df$matching_source[i] <- "All CPI: stringsim"
              df$coicop[i] <- max(possible_coicop)
              
        
              if(is.na(shop_rec)){
                
                
                df$matching_source[i] <- "All CPI: stringsim"
              }
              
              
            }
          }
          
        remove(dat_defined_reduced)
          
        } 
      }
    }
    
    
    if(df$art_name_match[i] == ""){
      str_split_res <- str_split_recursiv(article_name_rec, dat_defined)
      if(!is_empty(str_split_res$coicop)){
        df$art_name_match[i] <- str_split_res$artikelname
        df$coicop[i] <- str_split_res$coicop
        df$art_name[i] <- article_name_rec
        df$matching_source[i] <- "str_split"
      }
      
      
    }

    if(df$art_name_match[i] == ""){
      
      df$art_name_match[i] <- ""
      df$art_name[i] <- article_name_rec
      df$matching_source[i] <- "no_match_found"

      
    }  
    # the stopwatch for the process is stopped here and saved in the variable time_to_process
    df$time_to_process[i] <- str_sub(capture.output(toc()), 1, 5)
    
   
  }
  
  return(df)
  
  
}
