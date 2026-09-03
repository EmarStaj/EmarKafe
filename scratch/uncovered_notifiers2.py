import sys

def list_uncovered(file_path):
    stats = {}
    with open(file_path, 'r') as f:
        current_file = None
        for line in f:
            line = line.strip()
            if line.startswith('SF:'):
                current_file = line[3:]
                stats[current_file] = {'hits': {}}
            elif line.startswith('DA:'):
                parts = line[3:].split(',')
                line_num = int(parts[0])
                hits = int(parts[1])
                stats[current_file]['hits'][line_num] = hits

    for f, s in stats.items():
        if 'lib/state/notifiers/' in f:
            uncovered = [n for n, h in s['hits'].items() if h == 0]
            if uncovered:
                print(f"File {f} uncovered:")
                with open(f, 'r') as src:
                    lines = src.readlines()
                for n in uncovered:
                    print(f"  {n}: {lines[n-1].strip()}")

list_uncovered('coverage/lcov.info')
