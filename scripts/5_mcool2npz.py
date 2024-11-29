import numpy as np
from cooler import Cooler
from cooler.fileops import list_coolers

class HiCOol:
    def __init__(self, sra_id):
        self.sra_id = sra_id
        self.mcool_path = f'{sra_id}/{sra_id}.mcool'
        raw_resolutions = list_coolers(self.mcool_path)
        self.resolutions = [int(res.split('/')[-1]) for res in raw_resolutions]
        print(f"Available resolutions: {self.resolutions}")

    def extra_diag(self, matrix, window_size):
  
        print(f"Extracting sliding windows with size {window_size}...")
        diags = {}

        for d in range(-window_size, window_size + 1):  # Include negative and positive diagonals
            diags[d] = np.nan_to_num(matrix.diagonal(d).astype(np.float16))
        
        return diags

    def process_all(self, window_size):
 
        output_path = f"{self.sra_id}/{self.sra_id}.npz"
        data = {}

        for resolution in self.resolutions:
            cooler = Cooler(f'{self.mcool_path}::resolutions/{resolution}')
            resolution_data = {}

            for chrom in cooler.chromnames:
                print(f"Fetching data for chromosome: {chrom} at resolution: {resolution}")
                mat = cooler.matrix(balance=False,as_pixels=False,join=True).fetch(chrom)
                
                # Extract sliding window diagonals
                diags = self.extra_diag(mat, window_size)
                resolution_data[str(chrom)] = diags
            
            data[str(resolution)] = resolution_data

        # Save all data in one NPZ file
        print(f"Saving all resolutions to {output_path}...")
        np.savez(output_path, **data)
        print(f"Saved: {output_path}")


# Example Usage
if __name__ == "__main__":
    import argparse

    # Parse command-line arguments
    parser = argparse.ArgumentParser(description="Process .mcool file to NPZ format.")
    parser.add_argument("--sra_id", required=True, help="SRA ID of the dataset.")
    parser.add_argument("--window_size", type=int, default=64, help="Sliding window size.")
    args = parser.parse_args()

    # Create HiCOol object
    hicool = HiCOol(args.sra_id)

    # Process at the given resolution and window size
    hicool.process_all(args.window_size)