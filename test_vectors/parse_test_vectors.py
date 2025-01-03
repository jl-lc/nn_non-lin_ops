import re
import argparse

def parse_gelu_vectors():
  # Input and output file paths
  input_file = "gelu_test_vectors.h"
  output_file = "gelu_test_vectors.txt"

  # Open the .h file and read its content
  with open(input_file, "r") as infile:
    content = infile.read()

  # Regex to extract test vectors
  pattern = r'\{\s*\(int32_t\)0x([A-Fa-f0-9]+),\s*\(int32_t\)0x([A-Fa-f0-9]+),\s*\(int32_t\)0x([A-Fa-f0-9]+),\s*\(int32_t\)0x([A-Fa-f0-9]+),\s*\(int32_t\)0x([A-Fa-f0-9]+)\s*\}'
  matches = re.findall(pattern, content)

  # Write the extracted values to a text file
  with open(output_file, "w") as outfile:
    for match in matches:
      outfile.write(" ".join(match) + "\n")

  print(f"Converted {input_file} to {output_file}.")



def parse_ln_vectors():
  # Input and output file paths
  input_file = "ln_test_vectors.h"
  output_file = "ln_test_vectors.txt"

  # Open the .h file and read its content
  with open(input_file, "r") as infile:
    content = infile.read()

  # Define a regular expression to match the structure of the C-style test vectors
  vector_pattern = re.compile(
    r"\{\s*\{([^}]*)\},\s*"  # Match qin array
    r"\{([^}]*)\},\s*"       # Match bias array
    r"\{([^}]*)\}\s*"        # Match qout array
    r"\},"
  )

  # Find all matches of the test vectors in the content
  matches = vector_pattern.findall(content)

  # Process each match
  with open(output_file, "w") as outfile:
    for match in matches:
      # Clean up and keep the values in hexadecimal format
      qin = [re.sub(r"(\{)*\(int32_t\)(0x)", "", x.strip()) for x in match[0].split(",")]
      bias = [re.sub(r"\(int32_t\)(0x)", "", x.strip()) for x in match[1].split(",")]
      qout = [re.sub(r"\(int32_t\)(0x)", "", x.strip()) for x in match[2].split(",")]

      # Write the processed arrays to the output file
      outfile.write(f"{' '.join(qin)} | {' '.join(bias)} | {' '.join(qout)}\n")

  print(f"Converted {input_file} to {output_file}.")

def parse_sm_vectors():
    # Input and output file paths
    input_file = "sm_test_vectors.h"
    output_file = "sm_test_vectors.txt"

    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        content = infile.read()
        
        # Match individual test vectors
        vector_pattern = re.compile(
            r'\{\s*'
            r'\{(.*?)\},\s*'  # qin array
            r'\(int32_t\)0x([0-9A-Fa-f]+),\s*'  # qb
            r'\(int32_t\)0x([0-9A-Fa-f]+),\s*'  # qc
            r'\(int32_t\)0x([0-9A-Fa-f]+),\s*'  # qln2
            r'\(int32_t\)0x([0-9A-Fa-f]+),\s*'  # qln2_inv
            r'\(int32_t\)0x([0-9A-Fa-f]+),\s*'  # Sreq
            r'\{(.*?)\}\s*'  # qout array
            r'\}'
        )
        
        matches = vector_pattern.findall(content)
        
        for match in matches:
            qin = match[0]
            qb = match[1]
            qc = match[2]
            qln2 = match[3]
            qln2_inv = match[4]
            Sreq = match[5]
            qout = match[6]

            # Convert qin array
            qin_values = [re.sub(r"(\{)*\(int32_t\)(0x)", "", x.strip()) for x in qin.split(",")]

            # Convert qout array
            qout_values = [re.sub(r"\(int8_t\)(0x)", "", x.strip()) for x in qout.split(",")]

            # Write the processed arrays to the output file
            outfile.write(f"{' '.join(qin_values)} | {qb} | {qc} | {qln2} | {qln2_inv} | {Sreq} | {' '.join(qout_values)}\n")
    print(f"Converted {input_file} to {output_file}.")
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert test vectors to Verilog readable format")
    parser.add_argument("function", help="gelu / ln / sm")
    args = parser.parse_args()
    if (args.function == "gelu"):
        parse_gelu_vectors()
    if (args.function == "ln"):
        parse_ln_vectors()
    if (args.function == "sm"):
        parse_sm_vectors()