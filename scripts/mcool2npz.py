import numpy as np
from cooler import Cooler
from cooler.fileops import list_coolers


class HiCOol:
    def __init__(self, sra_id):
        """
        Initialize the HiCOol object.

        Parameters:
        - sra_id: The SRA ID associated with the dataset.
        """
        self.sra_id = sra_id
        self.mcool_path = f'{sra_id}/cooler/{sra_id}.mcool'
        self.resolutions = list_coolers(self.mcool_path)
        print(f"Available resolutions: {self.resolutions}")

    def extra_diag(self, matrix, window_size):
        """
        Extract sliding window diagonals from the given matrix.

        Parameters:
        - matrix: The input Hi-C matrix.
        - window_size: The size of the sliding window.

        Returns:
        - diags: A dictionary containing diagonal arrays.
        """
        print(f"Extracting sliding windows with size {window_size}...")
        diags = {}

        for d in range(-window_size, window_size + 1):  # Include negative and positive diagonals
            diags[d] = np.nan_to_num(matrix.diagonal(d).astype(np.float16))
        
        return diags

    def process(self, resolution, window_size):
        """
        Main process for converting .mcool file data to NPZ format.

        Parameters:
        - resolution: The resolution to load.
        - window_size: The size of the sliding window.

        Returns:
        - None
        """
        cooler = Cooler(f"{self.mcool_path}::resolutions/{resolution}")
        output_dir = f"{self.sra_id}/npz/"
        for chrom in cooler.chromnames:
            print(f"Fetching data for chromosome: {chrom}")
            mat = cooler.matrix(balance=True).fetch(chrom)
            
            # Extract sliding window diagonals
            diags = self.extra_diag(mat, window_size)
            
            # Save to NPZ file
            output_path = f"{output_dir}/{chrom}_{resolution}bp_{window_size}win.npz"
            print(f"Saving to {output_path}...")
            np.savez(output_path, **diags)
            print(f"Saved: {output_path}")

        print(f"Processing for resolution {resolution} completed.")


# Example Usage
if __name__ == "__main__":
    import argparse

    # Parse command-line arguments
    parser = argparse.ArgumentParser(description="Process .mcool file to NPZ format.")
    parser.add_argument("--sra_id", required=True, help="SRA ID of the dataset.")
    parser.add_argument("--resolution", type=int, required=True, help="Resolution to process.")
    parser.add_argument("--window_size", type=int, required=True, help="Sliding window size.")
    args = parser.parse_args()

    # Create HiCOol object
    hicool = HiCOol(args.sra_id)

    # Process at the given resolution and window size
    hicool.process(args.resolution, args.window_size)