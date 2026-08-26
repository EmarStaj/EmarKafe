import sys

def parse_lcov(file_path):
    stats = {}
    current_file = None
    lines_found = 0
    lines_hit = 0

    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('SF:'):
                current_file = line[3:]
                lines_found = 0
                lines_hit = 0
            elif line.startswith('LF:'):
                lines_found = int(line[3:])
            elif line.startswith('LH:'):
                lines_hit = int(line[3:])
            elif line == 'end_of_record':
                stats[current_file] = {'LF': lines_found, 'LH': lines_hit}

    return stats

def main():
    stats = parse_lcov('coverage/lcov.info')
    
    dirs = ['lib/state/notifiers/', 'lib/models/', 'lib/screens/']
    
    for d in dirs:
        total_lf = sum(s['LF'] for f, s in stats.items() if d in f)
        total_lh = sum(s['LH'] for f, s in stats.items() if d in f)
        pct = (total_lh / total_lf * 100) if total_lf > 0 else 0
        print(f"Coverage for {d}: {pct:.2f}% ({total_lh}/{total_lf})")

    total_lf = sum(s['LF'] for s in stats.values())
    total_lh = sum(s['LH'] for s in stats.values())
    pct = (total_lh / total_lf * 100) if total_lf > 0 else 0
    print(f"Overall Coverage: {pct:.2f}% ({total_lh}/{total_lf})")

if __name__ == '__main__':
    main()
