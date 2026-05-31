# Celebal_assignment_1
I successfully completed watching the vedios provided for week 1 learning and understood the use of pandas and its applications.
I completed my assignment 1 of week 1 using jupyter notebook as follows
1. I loaded the "Combined_dataset" csv file into dataframe, by importing pandas and usings pandas read_csv function.
2. I explored the dataset using head, tail ,shape ,columns ,dtypes.
   head() : I used head method to acess the first 5 rows of dataset and acessed first 3 by passing 3 as parameter.
   tail() : I used tail method to acess the last 5 rows of dataset .
   shape : I used shape property of pandas to know number of rows and columns in dataset.
   columns : I used columns attribute in pandas which returned all the column names of the dataset in the list.
   dtypes : I used dtypes attribute to know the data types of all the columns in the dataset.
3. I handled the missing values:
   isnull : I identified the null values in the dataset using isnull method.
   fillna : I filled the null values of numerical values with the median to preserve the distribution.
            I filled the non-numerical values with meaning full sentences.
   dropna : I droped the unecessary values in the dataset using dropna method.
4. I performed filtering by displaying the products which have rating above 4.5 and I selected columns by providing names of columns.
5. I removed the duplicates in the dataset by using drop_duplicates method.
6. To create a derived column , as "Quantity" column is not present in the "Combined_dataset" , I derived the "Sale_Category" column based on discount .
   If discount=0 then "No Sale"
   If discount<=20 then "Limited Offer"
   If discount<=50 then "Special Offer"
   If discount>50 then "Mega Sale"
7.I saved the Cleaned dataset into "cleaned_dataset" csv file using to_csv method.

   
