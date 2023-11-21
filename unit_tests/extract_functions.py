#!/usr/bin/env python3
import os
from pathlib import Path


def main():
    file_path = Path(os.path.abspath(__file__))
    install_script = file_path.parent / ".." / "install_script.sh.template"
    with install_script.open() as f:
        lines = f.readlines()
    in_function = False
    extracted_lines = []
    curly_brackets = ["{", "}"]
    bracket_counter = dict(zip(curly_brackets, 2*[0]))
    for line in lines:
        for bracket in curly_brackets:
            if bracket in line:
                bracket_counter[bracket] += 1
        if line.startswith("function"):
            in_function = True
            extracted_lines.append(line)
        elif line.startswith("}") and bracket_counter["{"] == bracket_counter["}"]:
            in_function = False
            extracted_lines.append(line)
        elif in_function:
            extracted_lines.append(line)
    extracted_file = file_path.parent / "extracted_functions.sh"
    with extracted_file.open(mode="w") as f:
        f.writelines(extracted_lines)



if __name__ == "__main__":
    main()
