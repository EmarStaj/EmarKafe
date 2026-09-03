import sys

def list_uncovered(file_path):
    stats = {}
    with open(file_path, 'r') as f:
        current_file = None
        for line in f:
            line = line.strip()
            if line.startswith('SF:'):
                current_file = line[3:]
                stats[current_file] = {'LF': 0, 'LH': 0}
            elif line.startswith('DA:'):
                parts = line[3:].split(',')
                line_num = parts[0]
                hits = int(parts[1])
            elif line.startswith('LF:'):
                stats[current_file]['LF'] = int(line[3:])
            elif line.startswith('LH:'):
                stats[current_file]['LH'] = int(line[3:])

    for f, s in stats.items():
        if 'lib/state/notifiers/' in f:
            print(f"{f}: {s['LH']}/{s['LF']}")

list_uncovered('coverage/lcov.info')
