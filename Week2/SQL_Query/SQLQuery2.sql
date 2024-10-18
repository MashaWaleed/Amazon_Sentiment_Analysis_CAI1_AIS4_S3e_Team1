-- Drop existing tables if they exist
DROP TABLE IF EXISTS FactReview;
DROP TABLE IF EXISTS DimDate;
DROP TABLE IF EXISTS DimProduct;
DROP TABLE IF EXISTS DimReviewer;
DROP TABLE IF EXISTS DimReview;
DROP TABLE IF EXISTS StagingFeedback;


-- Create the database
CREATE DATABASE CustomerFeedbackDB;

-- Use the new database
USE CustomerFeedbackDB;

-- Create the staging table
CREATE TABLE StagingFeedback (
    overall FLOAT,
    vote INT,
    verified BIT,
    reviewTime DATE,  -- Keeping it as NVARCHAR for flexibility
    reviewerID NVARCHAR(255),  -- Adjusted size to match Customers
    [asin] NVARCHAR(255),        -- Adjusted size to match Products
    style NVARCHAR(MAX),
    reviewerName NVARCHAR(255), -- Adjusted size to match Customers
    reviewText NVARCHAR(MAX),
    summary NVARCHAR(MAX)
);



-- Create the fact table
CREATE TABLE FactReview ( 
	id INT IDENTITY (1,1) PRIMARY KEY,
    reviewId INT, 
    overall DECIMAL(2,1) NOT NULL,           
    vote INT,                                 
    productId INT NOT NULL,                 
    reviewerId INT NOT NULL,                 
    dateId INT NOT NULL                      
);

-- Create date dimension table
CREATE TABLE DimDate (
    datePK INT PRIMARY KEY,           
    reviewDate DATE,                  
    [year] INT,                       
    [month] INT,                      
    [day] INT,                        
    [monthName] NVARCHAR(20),           
    [weekday] NVARCHAR(20),             
    [quarter] NVARCHAR(2)             
);


-- Create the foreign key constrains in fact table with date table by dateId and datePK
ALTER TABLE FactReview
ADD CONSTRAINT FK_Fact_Review_TimeID FOREIGN KEY (dateId) REFERENCES DimDate(datePK);

-- Create the product dimension table
CREATE TABLE DimProduct (
    productPK INT IDENTITY(1,1) PRIMARY KEY, 
    [asin] NVARCHAR(50) NOT NULL,               
    style NVARCHAR(MAX)                       
);

-- Create the foreign key constrains in fact table with product table by productId and productPK
ALTER TABLE FactReview 
ADD CONSTRAINT FK_Fact_Review_ProductID FOREIGN KEY (productId) REFERENCES DimProduct(productPK);


-- Create the reviewer dimension table
CREATE TABLE DimReviewer (
    reviewerPK INT IDENTITY(1,1) PRIMARY KEY, 
    reviewerId NVARCHAR(50) NOT NULL,          
    reviewerName NVARCHAR(255)                 
);


-- Create the foreign key constrains in fact table with reviewer table by reviewerId and reviewerPK
ALTER TABLE FactReview
ADD CONSTRAINT FK_Fact_Review_DimReviewer 
FOREIGN KEY (reviewerId) REFERENCES DimReviewer(reviewerPK);

-- Create the review dimension table
CREATE TABLE DimReview (
    reviewPK INT IDENTITY(1,1) PRIMARY KEY,  
    reviewText NVARCHAR(MAX),                
    summary NVARCHAR(MAX),                   
    verified BIT                             
);


-- Create the foreign key constrains in fact table with review table by reviewerId and reviewPK
ALTER TABLE FactReview
ADD CONSTRAINT FK_Fact_Review_DimReview 
FOREIGN KEY (reviewId) REFERENCES DimReview(reviewPK);


-- Insert into staging table
BULK INSERT StagingFeedback
FROM 'D:\Project\datasets\modified_cleaned_amazon_reviews_15000000.csv'  -- Update the path to your cleaned CSV
WITH (
    FIELDTERMINATOR = ',',  -- Specify the field delimiter
    ROWTERMINATOR = '\n',   -- Specify the row terminator
    FIRSTROW = 2,          -- Skip the header row
    KEEPNULLS               -- Keep NULLs (if any)
);

-- Insert the data into date table from staging table 
INSERT INTO DimDate (DatePK, reviewDate, [year], [month], [day], [monthName], [weekday], [quarter])
SELECT DISTINCT CAST (FORMAT(reviewTime,'yyyyMMdd') AS INT) AS DatePK,reviewTime , YEAR(reviewTime) AS [year], MONTH(reviewTime) AS [month], DAY(reviewTime) AS [day],DATENAME (MONTH, reviewTime) AS [monthName] , DATENAME (WEEKDAY, reviewTime) AS [weekday], 'Q' + DATENAME (QUARTER, reviewTime) AS [QUARTER] 
FROM StagingFeedback;

-- Insert the data into product table from staging table 
INSERT INTO DimProduct ([asin], style)
SELECT DISTINCT [asin], REPLACE (style, '"','') AS no_style 
FROM StagingFeedback;


-- Insert the data into reviewer table from staging table 
INSERT INTO DimReviewer (reviewerId,reviewerName)
SELECT DISTINCT reviewerID, 
    CASE 
        WHEN reviewerName IS NULL THEN 'Unknown name'
        ELSE reviewerName
    END AS reviewerName
FROM StagingFeedback;

-- Insert the data into review table from staging table
INSERT INTO DimReview (reviewText, summary, verified)
SELECT DISTINCT CASE WHEN reviewText IS NULL THEN 'No text'
					ELSE reviewText
					END AS reviewText
					, CASE WHEN summary IS NULL THEN 'No summary'
						ELSE summary 
						END AS summary
					, verified
FROM StagingFeedback;

--Insert insert the fact table
INSERT INTO FactReview (overall, vote, productId, reviewerId, dateId, reviewId)
SELECT s.overall,s.vote, dp.productPK, dr.reviewerPK, dd.datePK, dre.reviewPK
FROM StagingFeedback AS s 
LEFT JOIN DimProduct AS dp ON s.[asin] = dp.[asin] AND REPLACE (s.style, '"','') = dp.style
LEFT JOIN DimReviewer AS dr ON s.reviewerID = dr.reviewerId AND CASE 
        WHEN s.reviewerName IS NULL THEN 'Unknown name'
        ELSE s.reviewerName
		END = dr.reviewerName
LEFT JOIN DimDate AS dd ON s.reviewTime = dd.reviewDate
LEFT JOIN DimReview AS dre ON 
					CASE WHEN s.reviewText IS NULL THEN 'No text'
					ELSE s.reviewText
					END = dre.reviewText AND 
					CASE WHEN s.summary IS NULL THEN 'No summary'
						ELSE s.summary 
						END = dre.summary AND s.verified = dre.verified;


SELECT TOP 10 * FROM FactReview;
SELECT TOP 10 * FROM DimDate;
SELECT TOP 10 * FROM DimProduct;
SELECT TOP 10 * FROM DimReview;
SELECT TOP 10 * FROM DimReviewer;

------ the queries
-- 1. Get the total number of feedback entries
SELECT COUNT (*) AS TotalFeedback
FROM FactReview;

-- 2. Get the average rating for all products
SELECT AVG(overall) AS AverageRating
FROM FactReview;

-- 3. Get the top 10 products with the highest average rating and highest review count (minimum 5 reviews)
SELECT TOP 10 dp.[asin], AVG(fr.overall) AS AverageRating, COUNT (*) AS ReviewCount 
FROM FactReview AS fr JOIN DimProduct AS dp
ON fr.productId = dp.productPK
GROUP BY dp.asin
HAVING COUNT (*) >= 5
ORDER BY AverageRating DESC, ReviewCount DESC;

-- 4. Get the distribution of ratings
SELECT overall AS Rating, COUNT(*) AS Count
FROM FactReview
GROUP BY overall
ORDER BY overall;

-- 5. Get the top 5 customers with the most reviews
SELECT TOP 5 dr.reviewerId, COUNT (*) AS ReviewCount
FROM FactReview AS fr JOIN DimReviewer AS dr
ON fr.reviewerId = dr.reviewerPK
GROUP BY dr.reviewerId, dr.reviewerName
ORDER BY ReviewCount DESC;

-- 6. Get the average rating for verified vs. unverified purchases
SELECT dr.verified, AVG(fr.overall) AS AverageRating
FROM FactReview AS fr JOIN DimReview AS dr
ON fr.reviewId = dr.reviewPK
GROUP BY dr.verified;

-- 7. Get the monthly trend of average ratings
SELECT dd.[month], dd.[year], AVG(fr.overall) AS AveregeRating
FROM FactReview AS fr JOIN DimDate AS dd
ON fr.dateId = dd.datePK
GROUP BY dd.[month], dd.[year]
ORDER BY AveregeRating DESC, dd.[year] DESC, dd.[month] DESC;

-- 8. Get products with a significant difference between verified and unverified ratings
WITH RatingDiff AS (
		SELECT dp.[asin], AVG (CASE WHEN dr.verified = 1 THEN fr.overall END)AS VerifiedRating,
			   AVG (CASE WHEN dr.verified = 0 THEN fr.overall END) AS UnVerifiedRating
		FROM FactReview AS fr JOIN DimProduct AS dp
		ON fr.productId = dp.productPK
		JOIN DimReview AS dr
		ON fr.reviewId = dr.reviewPK 
		GROUP BY dp.[asin]
		HAVING COUNT(CASE WHEN dr.Verified = 1 THEN 1 END) >= 5
				AND COUNT(CASE WHEN dr.Verified = 0 THEN 1 END) >= 5
		)
SELECT TOP 10 *,  (VerifiedRating - UnVerifiedRating) AS RatingDifference
FROM RatingDiff 
ORDER BY ABS (VerifiedRating - UnVerifiedRating) DESC;

-- 9. Get the most common words in review summaries
WITH WordsList AS (
    SELECT value AS Word
    FROM DimReview
    CROSS APPLY STRING_SPLIT(LOWER(Summary), ' ')
)
SELECT TOP 20 Word, COUNT(*) AS Frequency
FROM WordsList
WHERE LEN(Word) > 3  -- Exclude short words
  AND Word NOT IN ('the', 'and', 'for', 'that', 'this', 'with', 'was', 'very')  -- Exclude common stop words
GROUP BY Word
ORDER BY Frequency DESC;

-- 10. Get products with sudden changes in average rating
WITH MonthlyRatings AS (
	SELECT dp.[asin], dd.[month], dd.[year], AVG (fr.overall) AS AverageRating
	FROM FactReview AS fr JOIN DimProduct dp
	ON fr.productId = dp.productPK
	JOIN DimDate AS dd
	ON fr.dateId = dd.datePK
	GROUP BY dp.[asin], dd.[month], dd.[year]
	),
RatingChanges AS (
	SELECT 
	        [asin],
	        [year],
	        [month],
	        AverageRating,
	        LAG(AverageRating) OVER (PARTITION BY [ASIN] ORDER BY [year], [month]) AS PreviousMonthRating,
	        AverageRating - LAG(AverageRating) OVER (PARTITION BY [asin] ORDER BY [year], [month]) AS RatingChange
	    FROM MonthlyRatings
	)
SELECT TOP 10 *
FROM RatingChanges
WHERE ABS(RatingChange) >= 1  -- Detect changes of 1 star or more
  AND PreviousMonthRating IS NOT NULL
ORDER BY ABS(RatingChange) DESC;

-- 11. The most positive reviwed product for each month
WITH CTE AS (
	SELECT dd.[year], dd.[month], dp.[asin] , AVG(fr.overall) AS RatingAverage, RANK () 
		OVER (PARTITION BY dd.[year], dd.[month] ORDER BY AVG(fr.overall) DESC) AS [rank]
	FROM FactReview AS fr 
	JOIN DimProduct AS dp
	ON fr.productId = dp.productPK
	JOIN DimDate AS dd
	ON fr.dateId = dd.datePK
	GROUP BY dd.[year], dd.[month], dp.[asin]
	)
SELECT [month], [year], [asin], RatingAverage
FROM CTE 
WHERE [rank] = 1
ORDER BY [year], [month]; 


-- 12. Most voted review for each product
WITH mostVotedReview AS (
	SELECT dp.[asin], fr.overall, dr.reviewText, dr.summary, fr.vote, RANK ()
		OVER (PARTITION BY dp.[asin] ORDER BY fr.vote) AS [rank]
	FROM FactReview AS fr 
	JOIN DimReview AS dr ON fr.reviewId = dr.reviewPK
	JOIN DimProduct AS dp ON fr.productId = dp.productPK
	WHERE fr.vote >= 1
),
averageForEachProduct AS(
	SELECT dp.[asin], AVG (fr.overall) AS averageRating
	FROM FactReview AS fr 
	JOIN DimProduct AS dp ON fr.productId = dp.productPK
	GROUP BY dp.[asin]
)
SELECT mvr.[asin], overall, reviewText, summary, vote, averageRating
FROM mostVotedReview AS mvr JOIN averageForEachProduct AS afep
ON mvr.[asin] = afep.[asin]
WHERE [rank] = 1
ORDER BY mvr.[asin];


