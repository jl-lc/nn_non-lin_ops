import numpy as np
import argparse

def exp(qin: np.int32, qb: np.int32, qc: np.int32, qln2: np.int32, qln2_inv: np.int32, fp_bits: int = 30) -> np.int32:
    fp_mul = np.int64(qin) * qln2_inv   # mul
    z = fp_mul >> fp_bits
    qp = qin - z * qln2                 # mul, sub
    ql = (qp + qb) * qp + qc            # poly
    qout = np.int32(ql >> z)            # shift
    return qout

def requant(qin: np.int32, bias: np.int32, m: np.int32, e: np.int8, out_bits: int=8, clip: bool=True) -> np.int32:
    '''
        qin - int32, input
        bias - int32, bias
        m - int32, requantization multiplier
        e - int8, requantization shifter
        out_bits - int, number of out bits
        qout - int32, output
    '''
    n = 2 ** (out_bits - 1) - 1
    qbias = qin + bias                  # int32
    qm = np.int64(qbias) * m            # int64
    qout = np.round(np.float64(qm) / 2.0**e)
    if clip: qout = np.clip(qout, -n-1, n)
    qout = np.int32(qout)
    return qout

def gen_exp(num_samples: int = 10000, output_file: str = "exp_test_vectors.txt"):
    """
    Generate random inputs, compute outputs using `exp`, and save them in a text file.
    """
    # Set ranges for random values
    qin_range = (-2**31, 2**31 - 1)
    qb_range = (-2**31, 2**31 - 1)
    qc_range = (-2**31, 2**31 - 1)
    qln2_range = (-2**31, 2**31 - 1)
    qln2_inv_range = (-2**31, 2**31 - 1)
    
    # Open file for writing
    with open(output_file, "w") as f:
        for _ in range(num_samples):
            # Generate random inputs
            qin = np.int32(np.random.randint(*qin_range))
            qb = np.int32(np.random.randint(*qb_range))
            qc = np.int32(np.random.randint(*qc_range))
            qln2 = np.int32(np.random.randint(*qln2_range))
            qln2_inv = np.int32(np.random.randint(*qln2_inv_range))
            
            # Compute output
            qout = exp(qin=qin, qb=qb, qc=qc, qln2=qln2, qln2_inv=qln2_inv)
            
            # Format inputs and outputs as hexadecimal
            qin_hex = f"{qin & 0xFFFFFFFF:08X}"
            qb_hex = f"{qb & 0xFFFFFFFF:08X}"
            qc_hex = f"{qc & 0xFFFFFFFF:08X}"
            qln2_hex = f"{qln2 & 0xFFFFFFFF:08X}"
            qln2_inv_hex = f"{qln2_inv & 0xFFFFFFFF:08X}"
            qout_hex = f"{qout & 0xFFFFFFFF:08X}"
            
            # Write to file
            f.write(f"{qin_hex} {qb_hex} {qc_hex} {qln2_hex} {qln2_inv_hex} {qout_hex}\n")

def format_as_twos_complement(value, bits=32):
    """
    Format an integer value as a two's complement hexadecimal string with the specified number of bits.
    """
    return f"{value & (2**bits - 1):0{bits // 4}X}"

def gen_req(num_samples: int = 10000, output_file: str = "req_test_vectors.txt"):
    """
    Generate random inputs, compute outputs using `requant`, and save them in a text file.
    """
    # Set ranges for random values
    qin_range = (-2**30, 2**30 - 1)
    bias_range = (-2**30, 2**30 - 1)
    m_range = (0, 2**31 - 1)
    # e_range = (0, 64)
    
    # Open file for writing
    with open(output_file, "w") as f:
        for _ in range(num_samples):
            # Generate random inputs
            qin = np.random.randint(*qin_range, dtype=np.int32)
            bias = np.random.randint(*bias_range, dtype=np.int32)
            m = np.random.randint(*m_range, dtype=np.int32)
            # e = np.random.randint(*e_range, dtype=np.int8)
            e = np.int8(30)
            
            # Compute output
            qout = requant(qin, bias, m, e)
            
            # Format inputs and outputs as hexadecimal
            qin_hex = format_as_twos_complement(qin)
            bias_hex = format_as_twos_complement(bias)
            m_hex = format_as_twos_complement(m)
            e_hex = format_as_twos_complement(e, bits=8)
            qout_hex = format_as_twos_complement(qout)
            
            # Write to file
            f.write(f"{qin_hex} {bias_hex} {m_hex} {e_hex} {qout_hex}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="generate test vectors for exp and requant")
    parser.add_argument("function", help="exp / req")
    args = parser.parse_args()
    if (args.function == "exp"):
        gen_exp()
    if (args.function == "req"):
        gen_req()