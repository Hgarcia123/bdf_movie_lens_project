# ETL - Transformation Steps
## movies
- Split 'title' by paratheses to get 'year'

## ratings
- convert 'rating' to int
- convert 'timestamp' from unix to date/string type 

# Potential storylines/features

## Verify year of rating vs year of release. Volume and average of ratings per year
This is interesting in order to check the number of ratings in other years than it's release. Some movies might get more popular in later years.