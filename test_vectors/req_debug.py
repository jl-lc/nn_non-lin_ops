import numpy as np

def requant(qin: np.int32, bias: np.int32, m: np.int32, e: np.int8, out_bits: int = 8, clip: bool = True):
    '''
        qin - int32, input
        bias - int32, bias
        m - int32, requantization multiplier
        e - int8, requantization shifter
        out_bits - int, number of out bits
        qout - int32, output
    '''
    intermediate_results = {}

    n = 2 ** (out_bits - 1) - 1
    intermediate_results["n"] = n

    qbias = qin + bias                  # int32
    intermediate_results["qbias"] = qbias

    qm = np.int64(qbias) * m            # int64
    intermediate_results["qm"] = qm

    qout = np.round(np.float64(qm) / 2.0**e)
    intermediate_results["qout_raw"] = qout

    if clip:
        qout = np.clip(qout, -n - 1, n)
    intermediate_results["qout_clipped"] = qout

    qout = np.int32(qout)
    intermediate_results["qout"] = qout

    return qout, intermediate_results

def format_as_twos_complement(value, bits=32):
    """
    Format an integer value as a two's complement hexadecimal string with the specified number of bits.
    """
    return f"{int(value) & (2**bits - 1):0{bits // 4}X}"

def read_vectors_and_compute_with_logging(input_file, output_file):
    """
    Reads test vectors from a file, computes the `requant` function, logs intermediate results,
    and saves them to an output file.
    """
    with open(input_file, "r") as infile, open(output_file, "w") as outfile:
        for line in infile:
            # Parse inputs
            qin_hex, bias_hex, m_hex, e_hex, _ = line.strip().split(" ")
            qin = np.int32(int(qin_hex, 16))
            bias = np.int32(int(bias_hex, 16))
            m = np.int32(int(m_hex, 16))
            e = np.int8(int(e_hex, 16))

            # Compute output and get intermediate results
            qout, intermediate_results = requant(qin, bias, m, e)

            # Write results to the output file
            outfile.write(f"Input: qin={qin_hex}, bias={bias_hex}, m={m_hex}, e={e_hex}\n")
            for name, value in intermediate_results.items():
                bits = 64 if isinstance(value, np.int64) else 32
                value_hex = format_as_twos_complement(value, bits)
                outfile.write(f"{name}: {value_hex}\n")
            outfile.write(f"Output: qout={format_as_twos_complement(qout)}\n\n")

if __name__ == "__main__":
    # Define input and output files
    input_file = "req_test_vectors.txt"
    output_file = "req_debug.txt"
    
    # Run the computation with logging
    read_vectors_and_compute_with_logging(input_file, output_file)
    print(f"Intermediate results written to {output_file}")
