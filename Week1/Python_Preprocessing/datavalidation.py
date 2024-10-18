import pandas as pd
import sys
import re
from datetime import datetime

def validate_data_types(df):
    """
    Validates and converts data types according to SQL staging table schema
    Returns cleaned dataframe and validation report
    """
    validation_report = []
    original_rows = len(df)
    
    try:
        # FLOAT validation for 'overall'
        df['overall'] = pd.to_numeric(df['overall'], errors='coerce')
        validation_report.append(f"overall: {df['overall'].isna().sum()} values couldn't be converted to float")
        
        # INT validation for 'vote'
        df['vote'] = pd.to_numeric(df['vote'], errors='coerce').fillna(0).astype(int)
        validation_report.append(f"vote: {df['vote'].isna().sum()} values couldn't be converted to int")
        
        # BIT validation for 'verified'
        if 'verified' in df.columns:
            df['verified'] = df['verified'].map({True: 1, False: 0, 1: 1, 0: 0})
            df['verified'] = df['verified'].fillna(0).astype(int)
            validation_report.append(f"verified: {df['verified'].isna().sum()} values couldn't be converted to bit")
        
        # String length validations for fixed-length fields
        for field in ['reviewerID', 'asin', 'reviewerName']:
            if field in df.columns:
                # Convert to string and truncate to 255 characters
                df[field] = df[field].astype(str).str.slice(0, 255)
                validation_report.append(f"{field}: {sum(df[field].str.len() > 255)} values were truncated")
        
        # Ensure text fields are strings
        for field in ['style', 'reviewText', 'summary']:
            if field in df.columns:
                df[field] = df[field].astype(str)
                
        # reviewTime validation (keeping as string but ensuring valid format)
        if 'reviewTime' in df.columns:
            df['reviewTime'] = df['reviewTime'].astype(str)
        
        # Remove rows where critical fields are null after type conversion
        critical_fields = ['overall', 'reviewerID', 'asin']
        for field in critical_fields:
            if field in df.columns:
                df = df.dropna(subset=[field])
        
        rows_after = len(df)
        rows_removed = original_rows - rows_after
        validation_report.append(f"\nRows removed due to critical null values: {rows_removed}")
        
        return df, validation_report
    
    except Exception as e:
        validation_report.append(f"Error during validation: {str(e)}")
        return df, validation_report

def clean_data(input_file, output_file):
    # Read the CSV file
    df = pd.read_csv(input_file)
    initial_rows = len(df)
    
    # Replace null votes with 0
    df['vote'] = df['vote'].fillna(0)
    
    # Convert verified column to binary
    if 'verified' in df.columns:
        df['verified'] = df['verified'].map({True: 1, False: 0})
    
    # Function to check if text contains alphabetical characters
    def has_alpha(text):
        if pd.isna(text):
            return False
        return bool(re.search('[a-zA-Z]', str(text)))
    
    # Remove rows where reviewText or summary is null or doesn't contain alphabetical characters
    df = df[df['reviewText'].apply(has_alpha) & df['summary'].apply(has_alpha)]
    
    # Validate and convert data types
    df, validation_report = validate_data_types(df)
    
    # Save the cleaned data
    df.to_csv(output_file, index=False)
    
    # Print statistics and validation report
    final_rows = len(df)
    print("\n=== Cleaning Report ===")
    print(f"Initial rows: {initial_rows}")
    print(f"Final rows: {final_rows}")
    print(f"Total removed rows: {initial_rows - final_rows}")
    print("\n=== Validation Report ===")
    for report_item in validation_report:
        print(report_item)
    
    # Print data types of final dataframe
    print("\n=== Final Data Types ===")
    for column, dtype in df.dtypes.items():
        print(f"{column}: {dtype}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python null_handler.py input.csv output.csv")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    clean_data(input_file, output_file)