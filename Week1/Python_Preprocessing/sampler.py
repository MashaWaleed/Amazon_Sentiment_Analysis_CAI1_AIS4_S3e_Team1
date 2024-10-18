import pandas as pd
import sys

def random_sample_csv(input_file, output_file, n_samples=1_500_000):
    # Read the CSV file
    df = pd.read_csv(input_file)
    
    # Check if we need to sample
    if len(df) > n_samples:
        # Random sample without replacement
        df = df.sample(n=n_samples, random_state=42)
    
    # Save the sampled data
    df.to_csv(output_file, index=False)
    print(f"Sampling complete. Output saved as: {output_file}")
    print(f"Original rows: {len(df)}")
    print(f"Sampled rows: {n_samples}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python random_sampler.py input.csv output.csv")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    random_sample_csv(input_file, output_file)