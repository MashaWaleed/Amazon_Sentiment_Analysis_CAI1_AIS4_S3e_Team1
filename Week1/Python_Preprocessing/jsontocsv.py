import pandas as pd
import json

# Load JSON data
with open('your_file.json', 'r') as f:
    data = json.load(f)

# Normalize and create a DataFrame
df = pd.json_normalize(data)

# Save to CSV
df.to_csv('output_file.csv', index=False)
