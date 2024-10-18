-- Drop existing tables if they exist
DROP TABLE IF EXISTS Feedback;
DROP TABLE IF EXISTS Products;
DROP TABLE IF EXISTS Customers;
DROP TABLE IF EXISTS FeedbackCategories;
DROP TABLE IF EXISTS StagingFeedback;

-- Create the database
CREATE DATABASE CustomerFeedbackDB;

-- Use the new database
USE CustomerFeedbackDB;
-- Create Customer table without unique constraint on ReviewerID
CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY IDENTITY(1,1),
    ReviewerID NVARCHAR(255) NOT NULL,
    ReviewerName NVARCHAR(255)
);

-- Create Product table without unique constraint on ASIN
CREATE TABLE Products (
    ProductID INT PRIMARY KEY IDENTITY(1,1),
    ASIN NVARCHAR(255) NOT NULL
);

-- Create FeedbackCategory table
CREATE TABLE FeedbackCategories (
    CategoryID INT PRIMARY KEY IDENTITY(1,1),
    CategoryName NVARCHAR(100) NOT NULL
);

-- Create Feedback table
CREATE TABLE Feedback (
    FeedbackID INT PRIMARY KEY IDENTITY(1,1),
    CustomerID INT NOT NULL,
    ProductID INT NOT NULL,
    CategoryID INT,
    Rating DECIMAL(2,1),
    ReviewText NVARCHAR(MAX),
    Summary NVARCHAR(MAX),
    ReviewTime DATETIME,
    Verified BIT,
    VoteCount INT,
    CONSTRAINT FK_Feedback_Customer FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    CONSTRAINT FK_Feedback_Product FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    CONSTRAINT FK_Feedback_Category FOREIGN KEY (CategoryID) REFERENCES FeedbackCategories(CategoryID)
);


-- Create the staging table
CREATE TABLE StagingFeedback (
    overall FLOAT,
    vote INT,
    verified BIT,
    reviewTime NVARCHAR(MAX),  -- Keeping it as NVARCHAR for flexibility
    reviewerID NVARCHAR(255),  -- Adjusted size to match Customers
    asin NVARCHAR(255),        -- Adjusted size to match Products
    style NVARCHAR(MAX),
    reviewerName NVARCHAR(255), -- Adjusted size to match Customers
    reviewText NVARCHAR(MAX),
    summary NVARCHAR(MAX)
);


BULK INSERT StagingFeedback
FROM 'C:\Users\mw296\OneDrive\Desktop\WORKS\PycharmProjects\jsonToCSV\modified_cleaned_amazon_reviews_15000000.csv'  -- Update the path to your cleaned CSV
WITH (
    FIELDTERMINATOR = ',',  -- Specify the field delimiter
    ROWTERMINATOR = '\n',   -- Specify the row terminator
    FIRSTROW = 2,          -- Skip the header row
    KEEPNULLS               -- Keep NULLs (if any)
);

-- Select all data from the StagingFeedback table
SELECT *
FROM StagingFeedback;

-- Insert customers into the Customers table, ignoring duplicates
INSERT INTO Customers (ReviewerID, ReviewerName)
SELECT DISTINCT reviewerID, reviewerName
FROM StagingFeedback
WHERE reviewerID IS NOT NULL;

-- Insert products into the Products table, ignoring duplicates
INSERT INTO Products (ASIN)
SELECT DISTINCT asin
FROM StagingFeedback
WHERE asin IS NOT NULL;

-- Insert feedback into the Feedback table
INSERT INTO Feedback (CustomerID, ProductID, Rating, ReviewText, Summary, ReviewTime, Verified, VoteCount)
SELECT 
    c.CustomerID,
    p.ProductID,
    s.overall AS Rating,
    s.reviewText,
    s.summary,
    TRY_CAST(s.reviewTime AS DATETIME) AS ReviewTime,
    s.verified AS Verified,
    s.vote AS VoteCount
FROM StagingFeedback s
JOIN Customers c ON s.reviewerID = c.ReviewerID
JOIN Products p ON s.asin = p.ASIN;

-- Select data from tables to verify insertion
SELECT TOP 100 * FROM Customers;
SELECT TOP 100 * FROM Products;
SELECT TOP 100 * FROM Feedback;


------ the queries
-- 1. Get the total number of feedback entries
SELECT COUNT(*) AS TotalFeedback
FROM Feedback;

-- 2. Get the average rating for all products
SELECT AVG(Rating) AS AverageRating
FROM Feedback;

-- 3. Get the top 10 products with the highest average rating (minimum 5 reviews)
SELECT TOP 10 p.ASIN, AVG(f.Rating) AS AverageRating, COUNT(*) AS ReviewCount
FROM Feedback f
JOIN Products p ON f.ProductID = p.ProductID
GROUP BY p.ASIN
HAVING COUNT(*) >= 5
ORDER BY AverageRating DESC;

-- 4. Get the distribution of ratings
SELECT Rating, COUNT(*) AS Count
FROM Feedback
GROUP BY Rating
ORDER BY Rating;

-- 5. Get the top 5 customers with the most reviews
SELECT TOP 5 c.ReviewerID, c.ReviewerName, COUNT(*) AS ReviewCount
FROM Feedback f
JOIN Customers c ON f.CustomerID = c.CustomerID
GROUP BY c.ReviewerID, c.ReviewerName
ORDER BY ReviewCount DESC;

-- 6. Get the average rating for verified vs. unverified purchases
SELECT Verified, AVG(Rating) AS AverageRating
FROM Feedback
GROUP BY Verified;

-- 7. Get the monthly trend of average ratings
SELECT YEAR(ReviewTime) AS Year, MONTH(ReviewTime) AS Month, AVG(Rating) AS AverageRating
FROM Feedback
GROUP BY YEAR(ReviewTime), MONTH(ReviewTime)
ORDER BY Year, Month;

-- 8. Get products with a significant difference between verified and unverified ratings
WITH RatingDiff AS (
    SELECT 
        p.ASIN,
        AVG(CASE WHEN f.Verified = 1 THEN f.Rating END) AS VerifiedRating,
        AVG(CASE WHEN f.Verified = 0 THEN f.Rating END) AS UnverifiedRating,
        ABS(AVG(CASE WHEN f.Verified = 1 THEN f.Rating END) - AVG(CASE WHEN f.Verified = 0 THEN f.Rating END)) AS RatingDifference
    FROM Feedback f
    JOIN Products p ON f.ProductID = p.ProductID
    GROUP BY p.ASIN
    HAVING COUNT(CASE WHEN f.Verified = 1 THEN 1 END) >= 5
       AND COUNT(CASE WHEN f.Verified = 0 THEN 1 END) >= 5
)
SELECT TOP 10 *
FROM RatingDiff
ORDER BY RatingDifference DESC;

-- 9. Get the most common words in review summaries
WITH WordsList AS (
    SELECT value AS Word
    FROM Feedback
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
    SELECT 
        p.ASIN,
        YEAR(f.ReviewTime) AS Year,
        MONTH(f.ReviewTime) AS Month,
        AVG(f.Rating) AS AverageRating
    FROM Feedback f
    JOIN Products p ON f.ProductID = p.ProductID
    GROUP BY p.ASIN, YEAR(f.ReviewTime), MONTH(f.ReviewTime)
),
RatingChanges AS (
    SELECT 
        ASIN,
        Year,
        Month,
        AverageRating,
        LAG(AverageRating) OVER (PARTITION BY ASIN ORDER BY Year, Month) AS PreviousMonthRating,
        AverageRating - LAG(AverageRating) OVER (PARTITION BY ASIN ORDER BY Year, Month) AS RatingChange
    FROM MonthlyRatings
)
SELECT TOP 10 *
FROM RatingChanges
WHERE ABS(RatingChange) >= 1  -- Detect changes of 1 star or more
  AND PreviousMonthRating IS NOT NULL
ORDER BY ABS(RatingChange) DESC;