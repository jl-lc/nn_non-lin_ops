import numpy as np
from typing import Tuple

def exp(expcount, qin: np.int32, qb: np.int32, qc: np.int32, qln2: np.int32, qln2_inv: np.int32, fp_bits: int = 30) -> Tuple[np.int32, dict]:
    """
    Compute the exponential approximation and record intermediate results.
    Returns the result and a dictionary of intermediate results.
    """
    intermediate_results = {}

    # Step-by-step computations with logging
    fp_mul = np.int64(qin) * qln2_inv  # mul
    intermediate_results['fp_mul' + str(expcount)] = fp_mul

    z = fp_mul >> fp_bits  # shift
    intermediate_results['z' + str(expcount)] = z

    qp = qin - z * qln2  # mul, sub
    intermediate_results['qp' + str(expcount)] = qp

    ql = (qp + qb) * qp + qc  # poly
    intermediate_results['ql' + str(expcount)] = ql

    qout = np.int32(ql >> z)  # shift
    intermediate_results['qout' + str(expcount)] = qout

    if expcount == 1:
        return qout, intermediate_results
    else:
        return qout, {}


def softmax(qin: np.int32, qb: np.int32, qc: np.int32, qln2: np.int32, qln2_inv: np.int32, Sreq: np.int32,
            fp_bits: int = 30, max_bits: int = 30, out_bits: int = 6) -> dict:
    """
    Perform softmax on the input while recording intermediate results.
    Returns a dictionary of all intermediate results.
    """
    intermediate_results = {}
    divident = 1 << max_bits  # uint32, constant
    shift = max_bits - out_bits

    # Inputs
    intermediate_results['qin'] = qin
    intermediate_results['qb'] = qb
    intermediate_results['qc'] = qc
    intermediate_results['qln2'] = qln2
    intermediate_results['qln2_inv'] = qln2_inv
    intermediate_results['Sreq'] = Sreq

    # Step-by-step computations with logging
    qmax = np.max(qin, axis=-1, keepdims=True)  # max, int32, reduction operation
    intermediate_results['qmax'] = qmax

    qhat = qin - qmax  # sub, int32
    intermediate_results['qhat'] = qhat

    # Call exp() for each element in qhat
    qexp_32 = []
    expcount = 0
    for val in qhat:
        exp_result, exp_intermediate_results = exp(expcount, qin=val, qb=qb, qc=qc, qln2=qln2, qln2_inv=qln2_inv, fp_bits=fp_bits)
        qexp_32.append(exp_result)
        intermediate_results.update(exp_intermediate_results)
        expcount = expcount + 1  
    intermediate_results['qexp_32'] = np.array(qexp_32, dtype=np.int32)

    qexp_64 = np.int64(qexp_32) * Sreq  # mul, int64
    intermediate_results['qexp_64'] = qexp_64

    qreq = np.round(np.float64(qexp_64) / 2.0**fp_bits)  # shift and round, int16
    qreq = np.int16(qreq)
    intermediate_results['qreq'] = qreq

    qsum = np.sum(qreq, axis=-1, keepdims=True, dtype=np.int32)  # acc, int32
    intermediate_results['qsum'] = qsum

    factor = np.floor(divident / qsum)  # div, constant / scalar
    factor = np.int32(factor)
    intermediate_results['factor'] = factor

    qout = qreq * factor  # mul
    qout = np.int8(qout >> shift)  # shift
    intermediate_results['qout'] = qout

    return intermediate_results


def format_as_twos_complement(value, bits=32):
    """
    Format an integer as a two's complement hexadecimal string.
    Handles both scalars and numpy arrays.
    """
    if isinstance(value, np.ndarray):
        return " ".join(f"0x{(int(x) & (2**bits - 1)):08X}" for x in value)
    else:
        return f"0x{(int(value) & (2**bits - 1)):08X}"
    

def read_vectors_and_compute_with_logging(input_file, output_file):
    """
    Reads the vectors from the text file, performs the layer_norm computation,
    logs intermediate results, and writes them to an output file.
    """
    count = 0
    with open(input_file, "r") as infile, open(output_file, "w") as outfile:
        for idx, line in enumerate(infile):
            # Split the line into components
            qin_hex, qb_hex, qc_hex, qln2_hex, qln2_inv_hex, Sreq_hex, _ = line.strip().split(" | ")

            # Convert hexadecimal strings to numpy arrays or scalars of int32
            qin = np.array([int(x, 16) for x in qin_hex.split()], dtype=np.int32)
            qb = int(qb_hex, 16)
            qc = int(qc_hex, 16)
            qln2 = int(qln2_hex, 16)
            qln2_inv = int(qln2_inv_hex, 16)
            Sreq = int(Sreq_hex, 16)

            # Perform softmax and get intermediate results
            results = softmax(qin=qin, qb=qb, qc=qc, qln2=qln2, qln2_inv=qln2_inv, Sreq=Sreq)

            # Write the intermediate results to the file
            outfile.write(f"Vector {idx}:\n")
            for key, value in results.items():
                # Use two's complement formatting for both arrays and scalars
                # print(f"Value: {value}, Type: {type(value)}")
                if (isinstance(value, np.int8)):
                    value_str = format_as_twos_complement(value, bits=8)
                elif (isinstance(value, np.int16)):
                    value_str = format_as_twos_complement(value, bits=16)
                elif (isinstance(value, np.int64)):
                    value_str = format_as_twos_complement(value, bits=64)
                else:  # Default to 32-bit formatting
                    value_str = format_as_twos_complement(value)
                outfile.write(f"{key}: {value_str}\n")
            outfile.write("\n")  # Blank line between vectors

            # just one line
            if count == 0:
              break
            count = count + 1

if __name__ == "__main__":
    # Define input and output files
    input_file = "sm_test_vectors.txt"
    output_file = "sm_debug.txt"
    
    # Run the computation with logging
    read_vectors_and_compute_with_logging(input_file, output_file)
    print(f"Intermediate results written to {output_file}")
