# r-recommender-with-drupal

Recommender (R language) with Drupal – July 2013
Rui Sarmento – email@ruisarmento.com

1. Install Drupal
2. Install Modules CTools, Data, Entity, Schema, Views, Voting API and module Five Star (can be other voting module) and activate those modules in Drupal
3. Install ODBC in OS with commands from 
http://asteriskdocs.org/en/3rd_Edition/asterisk-book-html-chunk/installing_configuring_odbc.html
4. Create ODBC connection to MySQL database in file odbc.ini 
- Edit “Database”, “UserName” and “Password” to be drupal’s chosen database name, db admin username and db admin password
5. Install R
- Run R with command “R” in OS console
- Install package “recommenderlab” in R console with command “install.packages("recommenderlab")”
- Install package “e1071” in R console with command “install.packages("e1071")”
- Install package “RODBC” in R console with command install.packages("RODBC")”
- Copy recommender_paper.R to root folder in server
6. In Drupal:
- Create Taxonomy Vocabulary with the category terms
- Create field in product/services pages for the ratings
- Make rule so that rating field be only accessible if the user A made exchange of products/services with user B
- Create mandatory category list field in product/service page so the proposing user can categorize his products/services
- With Data module adopt table “recommender” from db (after running the R script in 5.e.) 
- Create views block in user pages or other with the top5 or top10 recommended products/services for the user
    .This view uses “recommender” table
    .The column “rownames” in the previous table has the users ids
    .The other columns names correspond to the service/products ids 
    .The values for recommendation are from 0 to 100


IMPORTANT NOTES: 

Used tables in Drupal db:

“taxonomy_index” to get the product/services pages Id and its categories Id (nid and tid)
“votingapi_vote” to get the product/services ratings by the users (entity_id, uid and value)

Creates table in Drupal db:

“recommender” with column “rownames” with users Id and all other columns names correspond to items (services/products) Ids

Green Recommender:

The recommender only processes if there is new data to be process i.e. to say if a new voting is done or a new item appears in the db. For this process the .R script creates two data files data.RData and sim_matrixes.RData. NEVER delete this files or the recommender might use resources inefficiently and without need.

Suggestions:

Run the recommender R script with cron tasks scheduler or similar and once a day if the website has low traffic or several times a day if it has high traffic.
