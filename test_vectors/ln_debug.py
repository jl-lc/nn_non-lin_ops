import numpy as np

def layer_norm(qin: np.int32, bias: np.int32, shift: int = 6,
               n_inv: int = 1398101, max_bits: int = 31, fp_bits: int = 30) -> list:
    '''
    Perform layer normalization on the input while recording intermediate results.
    Returns a dictionary of all intermediate results.
    '''
    intermediate_results = {}
    divident = 1 << max_bits

    # Step-by-step computations with logging
    qsum = np.sum(qin, axis=-1, keepdims=True, dtype=np.int64)      # int64, acc
    intermediate_results['qsum'] = qsum

    q_shift = qin >> shift                                          # int32, shift
    intermediate_results['q_shift'] = q_shift

    q_sq = q_shift * q_shift                                        # int32, handled by mac
    intermediate_results['q_sq'] = q_sq

    qsum_sq = np.sum(q_sq, axis=-1, keepdims=True, dtype=np.int64)  # int64, mac
    intermediate_results['qsum_sq'] = qsum_sq

    qmul = qsum * n_inv                                             # int64, mul
    intermediate_results['qmul'] = qmul

    qmean = qmul >> fp_bits                                         # int32, shift
    intermediate_results['qmean'] = qmean

    r = qin - qmean                                                 # int32, sub
    intermediate_results['r'] = r

    qmean_mul = qmean * qsum                                        # int64, mul
    intermediate_results['qmean_mul'] = qmean_mul

    qmean_sq = qmean_mul >> (2 * shift)                             # int32, shift
    intermediate_results['qmean_sq'] = qmean_sq

    var = qsum_sq - qmean_sq                                        # int32, sub
    intermediate_results['var'] = var

    var_sqrt = np.floor(np.sqrt(var))                               # uint16, sqrt
    var_sqrt = np.uint16(var_sqrt)
    intermediate_results['var_sqrt'] = var_sqrt

    std = np.int32(var_sqrt) << shift                               # int32, shift
    intermediate_results['std'] = std

    factor = np.floor(divident / std.astype(np.float64))            # int32, div
    factor = np.int32(factor)
    intermediate_results['factor'] = factor

    qout_mul = np.int32(r * factor)                                 # int32, mul
    intermediate_results['qout_mul'] = qout_mul

    qout = (qout_mul >> 1) + bias                                   # int32, shift, add
    intermediate_results['qout'] = qout

    return intermediate_results


def format_as_twos_complement(value, bits=32):
    """
    Format an integer as a two's complement hexadecimal string.
    Handles both scalars and numpy arrays.
    """
    if isinstance(value, np.ndarray):
        return " ".join(f"0x{(x & (2**bits - 1)):08X}" for x in value)
    else:
        return f"0x{(value & (2**bits - 1)):08X}"
    

def read_vectors_and_compute_with_logging(input_file, output_file):
    """
    Reads the vectors from the text file, performs the layer_norm computation,
    logs intermediate results, and writes them to an output file.
    """
    count = 0
    with open(input_file, "r") as infile, open(output_file, "w") as outfile:
        for idx, line in enumerate(infile):
            
            if count < 32:
              count = count + 1
              continue

            # Split the line into components
            qin_hex, bias_hex, _ = line.strip().split(" | ")

            # Convert hexadecimal strings to numpy arrays of int32
            qin = np.array([int(x, 16) for x in qin_hex.split()], dtype=np.int32)
            bias = np.array([int(x, 16) for x in bias_hex.split()], dtype=np.int32)

            # Perform layer normalization and get intermediate results
            results = layer_norm(qin, bias)

            # Write the intermediate results to the file
            outfile.write(f"Vector {idx}:\n")
            for key, value in results.items():
                # Use two's complement formatting for both arrays and scalars
                value_str = format_as_twos_complement(value)
                outfile.write(f"{key}: {value_str}\n")
            outfile.write("\n")  # Blank line between vectors

            # just one line
            break

if __name__ == "__main__":
    # Define input and output files
    input_file = "ln_test_vectors.txt"
    output_file = "ln_debug.txt"
    
    # Run the computation with logging
    read_vectors_and_compute_with_logging(input_file, output_file)
    print(f"Intermediate results written to {output_file}")
