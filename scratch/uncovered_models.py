import sys

def list_uncovered(file_path):
    with open(file_path, 'r') as f:
        current_file = None
        for line in f:
            line = line.strip()
            if line.startswith('SF:'):
                current_file = line[3:]
            elif line.startswith('DA:'):
                parts = line[3:].split(',')
                line_num = parts[0]
                hits = int(parts[1])
                if hits == 0 and 'lib/models/' in current_file:
                    print(f"{current_file}:{line_num}")

list_uncovered('coverage/lcov.info')
