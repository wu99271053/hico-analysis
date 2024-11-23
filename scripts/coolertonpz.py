#!/usr/bin/env python
import argparse
import numpy as np
from cooler import Cooler
from pathlib import Path

def main(sra_id,window_size, balance=True):
    hic = Cooler(f'{sra_id}/input/cooler/{}')
    data = hic.matrix(balance=balance, sparse=True)
    # main loop
    for chrom in hic.chromnames:
        mat = data.fetch(chrom)
        diags = compress_diag(mat, window_size)
        ucsc_chrom = f'{chrom}.npz' if chrom.startswith('chr') else f'chr{chrom}.npz'
        chrom_path = save_path / ucsc_chrom
        np.savez(chrom_path, **diags)

def compress_diag(mat, window):
    # Pre-allocate a list for diagonals, size = 2 * window for both positive and negative diagonals
    diags = [None] * (2 * window)
    
    for d in range(window):
        # Store diagonals in the list, positive diagonals first, negative diagonals next
        diags[d] = np.nan_to_num(mat.diagonal(d).astype(np.float16))
        diags[window + d] = np.nan_to_num(mat.diagonal(-d).astype(np.float16))
    
    return diags

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Extract chromosome-matrix diagonals from mcool file')
    parser.add_argument('-s', '--sra_id', type=str,required=True,
                        help='sra_id')
    parser.add_argument('-w', '--window', type=int, default=128,
            help='Number of diagonals to extract [default: 256]')
    argv = parser.parse_args()
    
    main(sra_id=argv.sra_id,resolution=argv.resolution, window_size=argv.window, balance=argv.balance)


