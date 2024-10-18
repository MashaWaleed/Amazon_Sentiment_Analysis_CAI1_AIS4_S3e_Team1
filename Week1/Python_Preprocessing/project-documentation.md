# Amazon Reviews Data Processing Pipeline
## Project Documentation

### Overview
This documentation outlines our three-stage data processing pipeline designed to prepare Amazon review data for sentiment analysis. The pipeline consists of three Python scripts that handle data transformation, sampling, and cleaning operations.

### Pipeline Architecture
```
[JSON Data] → [JSON to CSV Converter] → [Random Sampler] → [Data Cleaner/Validator] → [Clean CSV Data]
```

### Stage 1: JSON to CSV Conversion
**Script: `json_to_csv.py`**

#### Purpose
- Transforms the raw JSON review data into a structured CSV format
- Handles large-scale data processing with memory efficiency
- Provides progress tracking during conversion

#### Key Features
- Line-by-line JSON processing to handle large files
- Progress bar implementation using `tqdm`
- Automated column mapping based on JSON structure

#### Usage
```bash
python json_to_csv.py input.json output.csv
```

#### Technical Specifications
- Input: Line-delimited JSON file
- Output: CSV file with standardized columns
- Dependencies: pandas, json, tqdm

---

### Stage 2: Data Sampling
**Script: `random_sampler.py`**

#### Purpose
- Reduces dataset to a manageable size of 1.5 million rows
- Maintains data distribution through random sampling
- Ensures reproducibility in the sampling process

#### Key Features
- Random sampling without replacement
- Fixed random seed for reproducibility
- Automatic sample size validation

#### Usage
```bash
python random_sampler.py input.csv sampled_output.csv
```

#### Technical Specifications
- Input: Full CSV dataset
- Output: Sampled CSV with 1.5M rows
- Dependencies: pandas
- Random seed: 42 (for reproducibility)

---

### Stage 3: Data Cleaning and Validation
**Script: `null_handler.py`**

#### Purpose
- Ensures data quality and consistency
- Handles missing values according to business rules
- Validates data types against SQL staging table requirements

#### Key Features
1. **Null Value Handling**
   - Votes: Replaces nulls with 0
   - Verified: Binary encoding (True→1, False→0)
   - Text fields: Removes rows with null or non-alphabetical content

2. **Data Type Validation**
   - Overall rating → FLOAT
   - Vote count → INT
   - Verified status → BIT
   - Text fields → NVARCHAR(MAX/255)

3. **Quality Checks**
   - String length validation
   - Character content validation
   - Critical field presence verification

#### Usage
```bash
python null_handler.py input.csv final_clean_output.csv
```

#### Technical Specifications
- Input: Sampled CSV data
- Output: Cleaned and validated CSV
- Dependencies: pandas, re
- SQL Staging Table Compatibility:
  ```sql
  CREATE TABLE StagingFeedback (
      overall FLOAT,
      vote INT,
      verified BIT,
      reviewTime NVARCHAR(MAX),
      reviewerID NVARCHAR(255),
      asin NVARCHAR(255),
      style NVARCHAR(MAX),
      reviewerName NVARCHAR(255),
      reviewText NVARCHAR(MAX),
      summary NVARCHAR(MAX)
  );
  ```

### Pipeline Metrics and Monitoring

#### Key Performance Indicators
1. **Data Volume Metrics**
   - Initial record count
   - Final record count
   - Records removed during cleaning

2. **Quality Metrics**
   - Null value counts
   - Data type conversion success rates
   - Text field validation results

3. **Processing Metrics**
   - Execution time per stage
   - Memory usage
   - Error rates

### Best Practices and Considerations

1. **Data Processing**
   - Run scripts in sequence
   - Verify output at each stage
   - Maintain backup of original data

2. **Error Handling**
   - Review validation reports
   - Monitor system resources
   - Keep logs of each run

3. **Performance Optimization**
   - Process during off-peak hours
   - Monitor memory usage
   - Use appropriate hardware resources

### Future Enhancements

1. **Potential Improvements**
   - Parallel processing capabilities
   - Advanced error logging
   - Automated pipeline orchestration
   - Real-time monitoring dashboard

2. **Scalability Considerations**
   - Cloud integration options
   - Distributed processing
   - Incremental data processing

### Conclusion
This pipeline provides a robust foundation for preparing Amazon review data for sentiment analysis. The modular design allows for easy maintenance and future enhancements while ensuring data quality and consistency throughout the process.
