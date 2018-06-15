 ###############################################
 #### Following South Korean Paper #############
 ###############################################
 #setwd("C:\\Users\\Rui Sarmento\\Documents\\Trabalho\\Sure Taste\\Code\\ml-100k")
 library("recommenderlab")
 library("e1071")
 library(RODBC)
 
 cat(paste("\nSTARTED ",format(Sys.time(),"%H:%M:%S %Y-%m-%d"),"\n"))
 

 ## TO DO - Connect to Drupal DB ##
 ch <- odbcConnect(dsn="drupal",uid="lets_dbadmin",pwd="1reload23")
 
####################################
######## db operations #############
####################################

prepare_DB <- function(tablename){

#Apaga os dados anteriores na tabela indicators da BD
truncate_table <- sqlDrop(ch,tablename)
}

read_DB <- function(ch, tablename){
df <- sqlFetch(ch, tablename, colnames = FALSE, rownames = TRUE)
}

write_DB <- function(df, tablename){
####Grava o Dataset para a BD em MySQL e de uma vez só####
grava_db <- sqlSave(ch,df,tablename, append=TRUE, rownames=TRUE, colnames=FALSE,verbose=FALSE,safer=FALSE,addPK=FALSE,fast=FALSE,test=FALSE,nastring=NULL)
}

#####################################
######## END - db operations ########
#####################################
 
 new_data <- FALSE
 ## READS DATA FROM BOTH SOURCES ##
 ## Connect to user voting tables and to items table with categories ##
 
 data_ratings_user <- read_DB(ch, "votingapi_vote")
 data_API <- read_DB(ch, "taxonomy_index")
 
 ## Check if there are new votings or new items in database tables ##
   
 if (!file.exists("data.RData")){

 #save rating and item  matrixes to check if there are new items or ratings next time it runs the recommender
 data_ratings_user_aux <- data_ratings_user
 data_API_aux <- data_API
 object_list <- c("data_ratings_user_aux", "data_API_aux")
 save(list = object_list,file="data.RData")
 } else {
 load("data.RData")
 if((dim(data_ratings_user_aux)[1]==dim(data_ratings_user)[1] && dim(data_ratings_user_aux)[2]==dim(data_ratings_user)[2]) && (dim(data_API_aux)[1]==dim(data_API)[1] && dim(data_API_aux)[2]==dim(data_API)[2]))
 	{
        cat(paste("\nEND ",format(Sys.time(),"%H:%M:%S %Y-%m-%d"),"\n"))
        stop("There is no new data to work with so program exit without processing")
  	}else{
        new_data <- TRUE
	#save rating and item  matrixes to check if there are new items or ratings next time it runs the recommender
 	data_ratings_user_aux <- data_ratings_user
	data_API_aux <- data_API
 	object_list <- c("data_ratings_user_aux", "data_API_aux")
	save(list = object_list,file="data.RData")
	}
 }


 # browser()
 names <-  sapply(levels(factor(data_API$"tid")),FUN=function(X){paste("cat",X,sep="")},USE.NAMES=FALSE)
 data_API <-  model.matrix( ~ -1+ nid + factor(data_API$"tid"),data_API)
 
 colnames(data_API) <- c("item_id",names)
 data_API <- rowsum(data_API, data_API[,"item_id"])
 data_API[,"item_id"] <- as.numeric(row.names(data_API))
 #uses only the items voted at least one time by the users
 data_API <- data_API[which(data_API[,"item_id"] %in% data_ratings_user$entity_id),]
 
 #browser()
 data_ratings_user <- as(data_ratings_user[,c(7,3,4)],"realRatingMatrix")

 
 #data_ratings_user <- read.csv("u.data", sep = "\t", header=FALSE)
 #data_ratings_user <- as(data_ratings_user,"realRatingMatrix")
 #data_API <- read.csv("u.item", sep = "|", header=FALSE)
 #colnames(data_API) <- c("movieid","movietitle","releasedate","videoreleasedate","IMDbURL","unknown","Action","Adventure","Animation","Children's","Comedy","Crime","Documentary","Drama","Fantasy","Film-Noir","Horror","Musical","Mystery","Romance","Sci-Fi","Thriller","War","Western")
 #data_API <- data_API[,-c(1,2,3,4,5)]
 #data_API <- as.matrix(data_API)
 
 ## if there are new data in tables previously opened then processes again...##
 if (!file.exists("sim_matrixes.RData") || new_data == TRUE){ 
 #browser()
 #Calculation of similarity matrix from user rating data
 sim_matrix_UR <- similarity(data_ratings_user, y = NULL, method = "pearson", args = NULL, which="items")
 
 #Calculation of clusters for API Data
 Fuzzy_Kmeans <- cmeans(data_API, centers=5, iter.max = 100, verbose = FALSE,dist = "euclidean", method = "cmeans", m = 2,rate.par = NULL, weights = 1, control = list())
 
 #new rating matrix from cluster membership
 Kmeans_cluster <- as(Fuzzy_Kmeans$membership,"realRatingMatrix")
 
 #browser()
 
 #Calculation of similarity between API items(restaurants/bars/nightlife ...)
 sim_matrix_API <- similarity(Kmeans_cluster, y = NULL, method = "cosine", args = NULL, which="users")
 
 sim_matrix_UR <- as.matrix(sim_matrix_UR)
 sim_matrix_API <- as.matrix(sim_matrix_API)
 
 #seting combination coefficient of similarity matrixes
 coeff <- 0.4
 
 #Aggregate similarity matrixes sim(k, l) = sim(k, l)item × (1 - c) + sim(k, l)group × c
 #browser()
 sim_aggregation = sim_matrix_UR * (1-coeff) +  sim_matrix_API * coeff
 
 #Calculation of similarity of users (for prediction)
 #and also K nearest neighbors from similarity matrix
 #sim_matrix_UR_pred <- similarity(data_ratings_user, y = NULL, method = "pearson", args = NULL, which="users")
 
 #Sorts similarity matrix, result is a list
 #sort_sim_list <- apply(sim_matrix_UR_pred,1, sort,(decreasing=TRUE))
 #returns object with k nearest neighbors for each user
 #kneighbors <- function(x,parameter) {return(names(x[2:(parameter+1)]))}
 #kneigh_per_user <- sapply(sort_sim_list,kneighbors, parameter=n )
 
 #save similarity matrixes to avoid recalculation of theses matrixes 
 object_list <- c("sim_matrix_UR", "sim_matrix_API", "sim_aggregation") 
 save(list = object_list,file="sim_matrixes.RData")
 }else{ 
 load("sim_matrixes.RData")
 #browser()
 }
 
 #number of neighbors to use
 n <- 30
 #TODO: Calculus of prediction for ratings and for each user 
 users <- rownames(data_ratings_user)
 
 #gets user ratings back to a matrix type for calculations 
 #of ratings predictions
 data_ratings_user <- as(data_ratings_user, "matrix")
 pred_user_item <- data_ratings_user
 #browser()
 #Takes already voted items out of prediction table and substitutes with NA's
 if (any( vote_index <- which(!is.na(pred_user_item[,])))) {pred_user_item[vote_index] = NA}
 
 #for each user in the list of user ratings
 #calculates the predictions for non voted items
 #by each user and populates the NA voting on the real ratings matrix
 #results are given on a data.frame for other uses
 #this for cycle can also be put aside for single user ratings prediction 
 for (u in users) {
 
 #initiate aux and aux2 for calculus
 aux <- 0
 aux1 <- 0
 aux2 <- 0
 
 
 #Unvoted items k by user u - has to be a vector of unvoted items
 item_k <- which(is.na(user_u_rating_item_i <- data_ratings_user[u,]))
 #for each item calculates k nearest neighbors
 for (item_k_n in item_k){ 
 item_k_neighbors <- sort(sim_aggregation[item_k_n,],decreasing=TRUE)
 #reinitiate aux variables for next item calculation
 aux <- 0
 aux1 <- 0
 aux2 <- 0
 #for n neighbors calculates
 for (i in names(item_k_neighbors)[1:n]){
 #browser()
 if(is.na(i) || is.na(data_ratings_user[u,i])){next} else {
 aux <- sum(aux,data_ratings_user[u,i]*sim_aggregation[item_k_n,i])
 #next line for implementation on equation 8 on paper
 aux1 <- sum(aux1, (data_ratings_user[u,i]-mean(data_ratings_user[,i], na.rm=TRUE))*sim_aggregation[item_k_n,i])
 aux2 <- sum(aux2,abs(sim_aggregation[item_k_n,i]))
 }}
 #outputs predicted rating on unvoted item if possible
	if (is.na(item_k_n_avg <- mean(data_ratings_user[,item_k_n], na.rm=TRUE)))
	{
    #(equation 9 on the paper)	
	pred_user_item[as.character(u), item_k_n] =  aux/aux2
	} else
		{
		#next line for implementation on equation 8 on paper
		pred_user_item[as.character(u), item_k_n] = sum(item_k_n_avg ,aux1/aux2)
		}
 }
 }
 
 TOPN <- function(user, n){
 return(sort(pred_user_item[user,], decreasing=TRUE)[1:n])
 }
 
 
 ###################################################
 #### END Following South Korean Paper #############
 ###################################################
 
 #browser()
 ## write on db the results for prediction of ratings in new products by each user ##
 ## first deletes the previous recommendation table ##
 
 prepare_DB("recommender")
 pred_user_item <- as.data.frame(pred_user_item)
 write_DB(pred_user_item, "recommender") 
 
 ## close dbs connection ##
 odbcClose(ch)
 
 cat(paste("\nEND ",format(Sys.time(),"%H:%M:%S %Y-%m-%d"),"\n"))
 #browser()
 
 
